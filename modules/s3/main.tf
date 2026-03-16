###############################################################################
# modules/s3/main.tf  –  Frontend static assets + Backend app-data buckets
###############################################################################

resource "random_id" "suffix" {
  byte_length = 4
}

# ── Frontend Bucket ───────────────────────────────────────────────────────────
resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.frontend_bucket_name}-${random_id.suffix.hex}"
  force_destroy = var.force_destroy

  tags = { Name = "${var.frontend_bucket_name}", Tier = "frontend" }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    filter { prefix = "" }
  }
}

# ── Backend Bucket ────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "backend" {
  bucket        = "${var.backend_bucket_name}-${random_id.suffix.hex}"
  force_destroy = var.force_destroy

  tags = { Name = "${var.backend_bucket_name}", Tier = "backend" }
}

resource "aws_s3_bucket_versioning" "backend" {
  bucket = aws_s3_bucket.backend.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backend" {
  bucket = aws_s3_bucket.backend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backend" {
  bucket                  = aws_s3_bucket.backend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backend" {
  bucket = aws_s3_bucket.backend.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    noncurrent_version_expiration {
      noncurrent_days = 60
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    filter { prefix = "" }
  }
}
