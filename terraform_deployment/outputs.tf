output "alb_public_ip" {
  description = "The public IP address of the ALB"
  value = aws_lb.quest_alb.dns_name
}
