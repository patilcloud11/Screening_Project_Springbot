###############################################################################
# modules/iam/main.tf
###############################################################################

# ─────────────────────────────────────────────
# Frontend EC2 Role
# ─────────────────────────────────────────────
resource "aws_iam_role" "frontend" {
  name = "${var.project_name}-frontend-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "frontend_s3" {
  name = "${var.project_name}-frontend-s3-policy-${var.environment}"
  role = aws_iam_role.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [var.frontend_s3_bucket, "${var.frontend_s3_bucket}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "frontend_ssm" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "frontend_cw_agent" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "frontend" {
  name = "${var.project_name}-frontend-profile-${var.environment}"
  role = aws_iam_role.frontend.name
}

# ─────────────────────────────────────────────
# Backend EC2 Role
# ─────────────────────────────────────────────
resource "aws_iam_role" "backend" {
  name = "${var.project_name}-backend-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "backend_s3" {
  name = "${var.project_name}-backend-s3-policy-${var.environment}"
  role = aws_iam_role.backend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [var.backend_s3_bucket, "${var.backend_s3_bucket}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "backend_cw_agent" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "backend" {
  name = "${var.project_name}-backend-profile-${var.environment}"
  role = aws_iam_role.backend.name
}

# ─────────────────────────────────────────────
# Lambda Role (Slack notifications)
# ─────────────────────────────────────────────
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
