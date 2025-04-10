provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "app_s3" {
  bucket = "app-s3-upload-bucket"
}

resource "aws_s3_bucket_ownership_controls" "upload_bucket" {
  bucket = aws_s3_bucket.app_s3.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "app_s3" {
  bucket = aws_s3_bucket.app_s3.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "app_s3" {
  bucket = aws_s3_bucket.app_s3.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "app_s3" {
  bucket = aws_s3_bucket.app_s3.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = "*",
      Action    = "s3:GetObject",
      Resource  = "${aws_s3_bucket.app_s3.arn}/*"
    }]
  })
}


# aws s3 cp index.html s3://app-s3-upload-bucket/index.html --acl public-read
