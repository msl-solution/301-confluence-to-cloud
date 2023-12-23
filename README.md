## Streamlining Atlassian Cloud Migration: Efficient Confluence Link Redirection

### The Importance of Redirection in Migration

Migrating to Atlassian Cloud presents a significant challenge: ensuring that existing Confluence links, which currently point to our on-premises instance, continue to function effectively. Merely redirecting users to the new wiki's homepage would be inadequate, as it would disrupt their access to specific content. To address this, we're implementing a redirection service. This service is crucial for maintaining the integrity of our Confluence link ecosystem during and after the migration, thereby ensuring a smooth transition for users and internal processes alike.

### Supported Link Formats

Our redirection strategy will encompass all three principal link formats, providing users with a seamless transition experience:

| Link Type           | Format                                                     | Example                                                       |
|---------------------|------------------------------------------------------------|---------------------------------------------------------------|
| Tiny URL            | `<scheme>://<fqdn>/<tiny_url_marker>/<tiny_url>`           | https://wiki.jtel.de/x/SQAF                                   |
| Pretty URL          | `<scheme>://<fqdn>/display/<space_key>/<page_name>`        | https://wiki.jtel.de/display/JPW/Supervisor+-+Realtime+Values |
| Direct Page ID URL  | `<scheme>://<fqdn>/pages/viewpage.action?pageId=<page_id>` | https://wiki.jtel.de/pages/viewpage.action?pageId=327753      |

### Redirection Strategy

Given that the migration alters page IDs, and since Tiny URLs are derived from these IDs, we cannot directly use page_id or tiny_url for redirection. Our solution focuses on using the page title, which remains consistent post-migration.

Initial dry-runs revealed that the Pretty URL format in Atlassian Cloud typically includes a `pages/<new_page_id>` structure. However, an alternative format allows for redirection without needing the new page ID: `<scheme>://<new_fqdn>/wiki/display/<space_key>/<page_name>`. This approach leverages the unchanged page titles for consistent redirection.

Our methodology, backed by insights from [Atlassian's documentation on Tiny URLs](https://confluence.atlassian.com/confkb/how-to-programmatically-generate-the-tiny-link-of-a-confluence-page-956713432.html) and [community discussions](https://community.atlassian.com/t5/Confluence-questions/What-is-the-algorithm-used-to-create-the-quot-Tiny-links-quot/qaq-p/186555), involves:

1. Extracting the current mapping of IDs to page titles.
2. Calculating the <tiny_url> and associating both pageId and <tiny_url> with the corresponding page title.

Consequently, we can redirect all link formats to `<scheme>://<new_fqdn>/wiki/display/<space_key>/<page_name>`, assuring users are directed to the appropriate content in the new environment.

### Mapping Process

#### Retrieving Page Titles and IDs

We employ the following SQL query to map page titles to IDs:

```sql
MYSQL_PASS="FIXME"
mysql \
  -uroot \
  -p"${MYSQL_PASS}" \
  -h 10.42.16.3 \
  -Dconfluence \
   --batch \
  -e "
SELECT CONCAT(S.LOWERSPACEKEY, '#', S.SPACENAME, '#', TITLE, '#', CONTENTID)
FROM CONTENT
JOIN SPACES S on CONTENT.SPACEID = S.SPACEID
WHERE CONTENTTYPE = 'PAGE'
    AND PREVVER IS NULL
    AND CONTENT_STATUS = 'current';
"
```

We use `#` as delimiter. The output is formatted and saved to `./provide-mapping/pages.csv`, and in our case looks like this:

```csv
head provide-mapping/pages.csv
jpw#jtel Portal WIKI#Supervisor - Realtime Values#327753
jpw#jtel Portal WIKI#Supervisor and Wallboard Content#327854
jpw#jtel Portal WIKI#Supervisor - Today's  Statistics#327852
...
```

#### Mapping Tiny URLs to Titles

Using a script, we generate the tiny URL for each page and map it to its title, substituting spaces with plus signs for direct usage.

```bash
docker run \
  --rm \
  -ti \
  -v .:/host \
  openresty \
    sh -c '
      cd /host/provide-mapping && \
      python3 generate_mapping.py > \
        /host/rootfs/app/mapping.csv
    '
```

This mapping serves as the foundation for our redirection mechanism:

```csv
head ./rootfs/app/mapping.csv
327753,SQAF,/jpw/Supervisor+-+Realtime+Values
327854,rgAF,/jpw/Supervisor+and+Wallboard+Content
327852,rAAF,/jpw/Supervisor+-+Today's++Statistics
...
```

### Implementing the Redirection

We instruct openresty to [load the mapping once at start time](./rootfs/app/init.lua) and use it in our [redirect code](./rootfs/app/main.lua).

#### Building and Using the Container

Set the migration target in the [redirection app](./rootfs/app/main.lua) and build the container.

```bash
docker build . -t openresty:latest
```

To deploy, run:

```bash
docker compose up
```

#### Testing the Setup

We perform tests using `curl` to ensure all link formats redirect correctly:

```bash
curl -v localhost/x/SQAF
curl -v localhost/pages/viewpage.action?pageId=327753
curl -v localhost/display/JPW/Supervisor+-+Realtime+Values
curl -v "localhost/x/SQAF?t=1&t=2"
curl -v "localhost/pages/viewpage.action?pageId=327753&t=1&t=2"
curl -v "localhost/display/JPW/Supervisor+-+Realtime+Values?t=1&t=2"
```

Each request should redirect to https://jtelgmbh.atlassian.net/wiki/display/JPW/Supervisor+-+Realtime+Values

##### Fallback Approach

Should this static mapping stop working because the URL format will be changed by Atlassian a fallback would be this format

`https://jtelgmbh.atlassian.net/wiki/pages/viewpage.action?spaceKey=JPW&title=Supervisor+-+Realtime+Values`
