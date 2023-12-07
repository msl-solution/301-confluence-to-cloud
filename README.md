## Support the migration of wiki.jtel.de

Currently wiki.jtel.de points to a self-hosted instance of confluence:
https://wiki.jtel.de -> VM, hosting confluence

After the migration it'll point to this redirect service
https://wiki.jtel.de -> openresty:80 (resolving tiny URLs and redirecting all calls to the target of the migration)

### Use the container

Set migration target in [redirect app](./rootfs/app/main.lua) and build the container.

```bash
docker build . -t openresty:latest
```

The container can then be started via

```bash
docker compose up
```

#### Test

```bash
# Resolve to log URL using page title
curl -v localhost/FYhhB

# Redirect as is
curl -v localhost/FYhhBwerg

# Resolve to log URL using page title, keep parameters
curl -v localhost/FYhhB?wth

# Redirect as is, keep parameters
curl -v localhost/pages/viewpage.action?pageId=327789
```


### Why, oh why?

Currently, the JTEL application relies heavily on short links to wiki.jtel.de, for example, https://wiki.jtel.de/x/TgAF, which maps to https://wiki.jtel.de/display/JPW/jtel-Portal+WIKI.

We now need to rewrite these abbreviated URLs to the destination of our migration, like https://wiki.jtel.de/x/TgAF to https://jtelgmbh.atlassian.net/wiki/spaces/JPW/jtel-Portal+WIKI.

The abbreviated URL is not stored in the database but is generated based on the content ID of the page. Although it's possible to infer the ID from the tiny URL and use this ID directly (e.g., https://wiki.jtel.de/pages/viewpage.action?pageId=2163916), we cannot rely on it for referencing the page, as this ID is expected to change during the migration.

Therefore, we need to

- Retrieve the mapping of page titles to IDs for wiki.jtel.de
- Calculate the tiny URL and map it to a page title
- Utilize this mapping as the source for our redirection mechanism.

#### Retrieve the current mapping of page titles to IDs

```sql
SELECT S.LOWERSPACEKEY, S.SPACENAME, TITLE, CONTENTID
FROM CONTENT
JOIN SPACES S on CONTENT.SPACEID = S.SPACEID
WHERE CONTENTTYPE = 'PAGE'
    AND PREVVER IS NULL
    AND CONTENT_STATUS = 'current';
```

and save the output to `./provide-mapping/pages.csv` so that it looks like this

```csv
head ./provide-mapping/pages.csv
jpw,jtel Portal WIKI,Supervisor - Realtime Values,327753
jpw,jtel Portal WIKI,Supervisor and Wallboard Content,327854
jpw,jtel Portal WIKI,Supervisor - Today's  Statistics,327852
jpw,jtel Portal WIKI,Supervisor - Inbound Media Events,327863
jpw,jtel Portal WIKI,Supervisor - Wallboard Total,327879
jpw,jtel Portal WIKI,Supervisor - Wallboard Graphics,327940
jpw,jtel Portal WIKI,Supervisor - Group Details,327948
jpw,jtel Portal WIKI,jtel Portal WIKI,327758
...
```

#### Calculate the tiny URL and map it to a page title

In addition to [generating the tiny URL from the page ID and associating it with a title](./provide-mapping/generate_mapping.py), we substitute all spaces with a plus sign. This allows us to use the modified page title directly, thereby saving the redirect code from performing this task.

```bash
docker run \
  --rm \
  -ti \
  -v .:/host \
  floriankessler/openresty \
    sh -c '
      cd /host/provide-mapping && \
      python3 generate_mapping.py > \
        /host/rootfs/app/mapping.csv
    '
```

It looks like this:

```csv
head ./rootfs/app/mapping.csv
SQAF,/jpw/Supervisor+-+Realtime+Values
rgAF,/jpw/Supervisor+and+Wallboard+Content
rAAF,/jpw/Supervisor+-+Today's++Statistics
twAF,/jpw/Supervisor+-+Inbound+Media+Events
xwAF,/jpw/Supervisor+-+Wallboard+Total
BAEF,/jpw/Supervisor+-+Wallboard+Graphics
DAEF,/jpw/Supervisor+-+Group+Details
TgAF,/jpw/jtel+Portal+WIKI
...
```

#### Utilize this mapping as the source for our redirection mechanism

We instruct openresty to [load the mapping once at start time](./rootfs/app/init.lua) and use that dict in our [redirect code](./rootfs/app/main.lua).

### Source

https://confluence.atlassian.com/confkb/how-to-programmatically-generate-the-tiny-link-of-a-confluence-page-956713432.html
https://community.atlassian.com/t5/Confluence-questions/What-is-the-algorithm-used-to-create-the-quot-Tiny-links-quot/qaq-p/186555

https://wiki.jtel.de/pages/tinyurl.action?urlIdentifier=DYlhB
https://wiki.jtel.de/x/DYlhB

https://wiki.jtel.de/pages/viewpage.action?pageId=2163916
