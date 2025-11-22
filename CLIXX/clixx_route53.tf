# ----------------------------------------
# Story: Route53 DNS for Clixx
# ----------------------------------------

# Fetch the hosted zone for nancy-stack.com
data "aws_route53_zone" "nancy_stack" {
  name         = "nancy-stack.com."
  private_zone = false
}

# Create the DEV DNS record → ALB
resource "aws_route53_record" "clixx_dev" {
  zone_id = data.aws_route53_zone.nancy_stack.zone_id
  name    = "dev.clixx.nancy-stack.com"
  type    = "CNAME"
  ttl     = 60

  records = [aws_lb.clixx_alb.dns_name]
}
