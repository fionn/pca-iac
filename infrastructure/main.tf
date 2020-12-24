locals {
  name   = "pki-test"
  domain = "pki.sec.example.com"
}

locals {
  common_tags = {
    Project = "sec-${local.name}"
    Env     = "staging"
    Name    = local.name
  }
}

resource "aws_acmpca_certificate_authority" "example" {
  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name                  = "${local.name}.${local.domain}"
      country                      = "HK"
      distinguished_name_qualifier = ""
      organization                 = "Example Organisation"
      organizational_unit          = "PKI Division"
    }
  }

  revocation_configuration {
    crl_configuration {
      custom_cname       = "crl.${local.domain}"
      enabled            = false
      expiration_in_days = 7
      s3_bucket_name     = aws_s3_bucket.crl.id
    }
  }

  depends_on = [aws_s3_bucket_policy.crl]

  type = "SUBORDINATE"

  enabled                         = false
  permanent_deletion_time_in_days = 7

  tags = local.common_tags
}

resource "aws_s3_bucket" "crl" {
  bucket_prefix = replace("${local.name}-crl-${local.domain}-", ".", "-")
  acl           = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = local.common_tags
}

data "aws_iam_policy_document" "acmpca_bucket_access" {
  statement {
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]

    resources = [
      aws_s3_bucket.crl.arn,
      "${aws_s3_bucket.crl.arn}/*",
    ]

    principals {
      identifiers = ["acm-pca.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_s3_bucket_policy" "crl" {
  bucket = aws_s3_bucket.crl.id
  policy = data.aws_iam_policy_document.acmpca_bucket_access.json
}
