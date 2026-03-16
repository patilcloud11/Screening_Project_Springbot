output "distribution_id"          { value = aws_cloudfront_distribution.main.id }
output "distribution_domain_name" { value = aws_cloudfront_distribution.main.domain_name }
output "distribution_arn"         { value = aws_cloudfront_distribution.main.arn }
output "oai_iam_arn"              { value = aws_cloudfront_origin_access_identity.oai.iam_arn }
output "origin_secret" {
  value     = random_password.origin_secret.result
  sensitive = true
}
