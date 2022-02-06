output "user_data_base64" {
  value = null
}
output "vpc_cidr" {
  value = data.aws_vpc.primary.cidr_block
}