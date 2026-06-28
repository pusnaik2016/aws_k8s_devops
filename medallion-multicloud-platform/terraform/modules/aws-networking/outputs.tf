# =============================================================================
# AWS Networking Module — Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_compute_subnet_ids" {
  description = "IDs of the private compute subnets (Databricks clusters)"
  value       = aws_subnet.private_compute[*].id
}

output "private_data_subnet_ids" {
  description = "IDs of the private data subnets (VPC endpoints)"
  value       = aws_subnet.private_data[*].id
}

output "databricks_compute_sg_id" {
  description = "Security group ID for Databricks compute nodes"
  value       = aws_security_group.databricks_compute.id
}

output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC interface endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 gateway VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "dx_gateway_id" {
  description = "ID of the Direct Connect gateway (if enabled)"
  value       = var.enable_cross_cloud_transit ? aws_dx_gateway.cross_cloud[0].id : null
}

output "vpn_gateway_id" {
  description = "ID of the VPN gateway (if enabled)"
  value       = var.enable_cross_cloud_transit ? aws_vpn_gateway.main[0].id : null
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT gateways"
  value       = aws_eip.nat[*].public_ip
}
