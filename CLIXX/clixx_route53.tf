# ----------------------------------------
# Story: Route53 DNS for Clixx
# ----------------------------------------

# Fetch the hosted zone for nancy-stack.com
data "aws_route53_zone" "selected_zone" {
  name         = "${var.root_domain}."
  private_zone = false
}

resource "aws_route53_record" "clixx_env_record" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id

  # dev.clixx.nancy-stack.com
  name = "${var.clixx_subdomain}.${var.root_domain}"

  type = "CNAME"
  ttl  = 60

  records = [aws_lb.clixx_alb.dns_name]
}
