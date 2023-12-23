import base64
import csv
from typing import List, Tuple

# Point to the result of our SQL query
csv_file = "pages.csv"
csv_delimiter='#'

prefix_tiny_url = ""

# Function to convert spaces to plus signs in a string
def replace_spaces_with_plus(title: str) -> str:
    return title.replace(" ", "+")

# Function to convert page IDs to tiny URLs
def convert_page_ids_to_tiny_urls(page_ids: List[int], page_spaces: List[str], modified_titles: List[str]) -> List[str]:
    tiny_urls: List[str] = []

    for page_id, page_space, modified_title in zip(page_ids, page_spaces, modified_titles):
        # Convert the page ID to a tiny URL part
        encoded = base64.b64encode(page_id.to_bytes(4, byteorder='little')).decode()
        encoded_fixed = encoded.replace("/", "-").replace("+", "_").rstrip('A=')
        tiny_url = f"{prefix_tiny_url}{encoded_fixed}"
        tiny_urls.append(f"{page_id},{tiny_url},/{page_space}/{replace_spaces_with_plus(modified_title)}")

    return tiny_urls

# Function to read page IDs, page titles, and space values from a CSV file
def read_csv_file(csv_file: str) -> Tuple[List[int], List[str], List[str]]:
    page_ids: List[int] = []
    page_titles: List[str] = []
    page_spaces: List[str] = []

    try:
        with open(csv_file, mode='r') as file:
            # reader = csv.reader(file)
            reader = csv.reader(file, delimiter=csv_delimiter)
            for row in reader:
                page_id = int(row[3])
                page_title = row[2]
                page_space = row[0]
                page_ids.append(page_id)
                page_titles.append(page_title)
                page_spaces.append(page_space)
    except FileNotFoundError:
        print(f"Error: File {csv_file} not found.")

    return page_ids, page_titles, page_spaces

def main():
    page_ids, page_titles, page_spaces = read_csv_file(csv_file)

    # Modify page titles
    modified_titles = [replace_spaces_with_plus(title) for title in page_titles]

    # Convert page IDs to tiny URLs with space values and modified titles
    tiny_urls = convert_page_ids_to_tiny_urls(page_ids, page_spaces, modified_titles)

    # Print out the arrays of tiny URLs and full URLs
    for tiny_url in tiny_urls:
        print(tiny_url)

if __name__ == "__main__":
    main()
