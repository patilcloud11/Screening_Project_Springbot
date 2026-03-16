output "frontend_bucket_name"            { value = aws_s3_bucket.frontend.bucket }
output "backend_bucket_name"             { value = aws_s3_bucket.backend.bucket }
output "frontend_bucket_arn"             { value = aws_s3_bucket.frontend.arn }
output "backend_bucket_arn"              { value = aws_s3_bucket.backend.arn }
output "frontend_bucket_regional_domain" { value = aws_s3_bucket.frontend.bucket_regional_domain_name }
output "backend_bucket_regional_domain"  { value = aws_s3_bucket.backend.bucket_regional_domain_name }
