output "frontend_instance_profile_name" { value = aws_iam_instance_profile.frontend.name }
output "backend_instance_profile_name"  { value = aws_iam_instance_profile.backend.name }
output "lambda_role_arn"                { value = aws_iam_role.lambda.arn }
output "frontend_role_arn"              { value = aws_iam_role.frontend.arn }
output "backend_role_arn"               { value = aws_iam_role.backend.arn }
