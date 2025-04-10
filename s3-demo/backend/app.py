from flask import Flask, request
import boto3
import os

app = Flask(__name__)

s3 = boto3.client('s3')
BUCKET_NAME = "my-app-image-upload-bucket-unique-name"  # same as in s3.tf

@app.route("/", methods=["GET"])
def home():
    return "Upload Service Ready!"

@app.route("/upload", methods=["POST"])
def upload_file():
    file = request.files.get("file")
    if file:
        s3.upload_fileobj(file, BUCKET_NAME, file.filename)
        return f"File {file.filename} uploaded successfully!"
    return "No file provided.", 400

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
