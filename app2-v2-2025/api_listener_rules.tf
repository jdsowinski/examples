# Anonymized ALB listener rule patterns; illustrative only.

resource "aws_lb_listener_rule" "deny_path" {
  listener_arn = var.https_listener_arn
  priority     = var.deny_rule_priority

  condition {
    path_pattern {
      values = ["/v1/restricted", "/v1/restricted/*"]
    }
  }

  condition {
    host_header {
      values = var.hostnames
    }
  }

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  tags = local.default_tags
}

resource "aws_lb_listener_rule" "redirect_path" {
  listener_arn = var.https_listener_arn
  priority     = var.redirect_rule_priority

  condition {
    path_pattern {
      values = ["/v1/legacy-endpoint", "/v1/legacy-endpoint/*"]
    }
  }

  condition {
    host_header {
      values = var.hostnames
    }
  }

  action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      path        = "/v1/current-endpoint"
      query       = "#{query}"
      status_code = "HTTP_301"
    }
  }

  tags = local.default_tags
}
