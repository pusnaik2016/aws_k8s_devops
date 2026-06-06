"""
Bulk Upload Questions from CSV
Author: Pushparaj Naik

Usage: python bulk_upload_questions.py <csv_file> <api_url>
Example: python bulk_upload_questions.py questions-answers/aws.csv http://localhost:8000
"""
import csv
import json
import sys
import requests

def parse_csv(file_path):
    """Parse CSV file and return list of question dictionaries"""
    questions = []

    with open(file_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)

        for row in reader:
            try:
                # Skip empty rows
                if not any(row.values()):
                    continue

                question = {
                    'topic_slug': row.get('topic_slug', '').strip(),
                    'question_text': row.get('question_text', '').strip(),
                    'options': [
                        row.get('option_1', '').strip(),
                        row.get('option_2', '').strip(),
                        row.get('option_3', '').strip(),
                        row.get('option_4', '').strip()
                    ],
                    'correct_answer': int(row.get('correct_answer', 0))
                }

                # Validate
                if question['question_text'] and all(question['options']):
                    questions.append(question)
                else:
                    print(f"Skipping invalid row: {row}")

            except (ValueError, KeyError) as e:
                print(f"Error parsing row: {e}")
                continue

    return questions

def upload_questions(questions, api_url):
    """Upload questions to the API"""
    url = f"{api_url}/api/quiz/questions/bulk"

    try:
        response = requests.post(
            url,
            json=questions,
            headers={'Content-Type': 'application/json'}
        )

        result = response.json()
        print(f"\nUpload Results:")
        print(f"  Success: {result.get('success', 0)}")
        print(f"  Failed: {result.get('failed', 0)}")

        if result.get('errors'):
            print(f"  Errors:")
            for error in result['errors']:
                print(f"    - {error}")

        return result

    except requests.exceptions.ConnectionError:
        print(f"Error: Could not connect to {api_url}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python bulk_upload_questions.py <csv_file> <api_url>")
        print("Example: python bulk_upload_questions.py questions-answers/aws.csv http://localhost:8000")
        sys.exit(1)

    csv_file = sys.argv[1]
    api_url = sys.argv[2].rstrip('/')

    print(f"Parsing CSV file: {csv_file}")
    questions = parse_csv(csv_file)
    print(f"Found {len(questions)} valid questions")

    if questions:
        print(f"Uploading to: {api_url}")
        upload_questions(questions, api_url)
    else:
        print("No valid questions found in CSV file")
