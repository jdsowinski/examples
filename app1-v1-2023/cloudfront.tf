# Anonymized excerpt from the original CDN configuration; not deployable.

resource "aws_cloudfront_distribution" "assets" {
  depends_on = [aws_acm_certificate_validation.certificate]

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront for ${var.application_name}"
  aliases         = [for domain in var.attached_domains : "assets.${domain}"]

  origin {
    domain_name = var.assets_s3_bucket
    origin_id   = "s3-origin"
    origin_path = "/${var.application_name}/wp-content/uploads"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(local.tags, {
    Name = "${var.application_name}-cdn"
  })
}
