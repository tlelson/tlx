def main():
    try:
        import boto3
        import click
        print("boto3 and click are installed and importable.")
    except ImportError as e:
        print("ImportError:", e)
        exit(1)
