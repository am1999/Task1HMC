provider "aws" {
  region     = "ap-south-1"
 profile = "terrapro"
}


resource "aws_key_pair" "keytask" {
  key_name   = "keytask"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAp1J879tIXn7/s/lKuUrNpoTJC/qE45ONAa9Nt+TfLDpg05kJdaCQSVtyMxn41t3aL/I50+h+9gWvZZ/l1gKLtAj9IlGfk3wALv2KtvPcdgPUXKQarKd/pi3GwdX+HWEonxsm5wNQmsIRj/6GC5WRL7b8TJqkCHhjda5qx59C52aCzGiTWPvB/LQYsJtZpSOZOc2BOXk24MYFbl4avM9W/WGWNR6qdUp3wCT4NUfZcMotFDnh92puTsjaWd+k6cnL/TjkmAobkwVLEIe+C9Gge0Izi2a69T3If6b4sUHyJer87E47PomEHYv9wNRFANssDRiUsD1jaPaCP244sCURwQ== rsa-key-20200614"
}


resource "aws_security_group" "sgtask" {
  name        = "sgtask"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "vpc-b1c59dd9"

ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks=["0.0.0.0/0"]
  }
ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks=["0.0.0.0/0"]
  }
egress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks=["0.0.0.0/0"]
  }
egress {
    description = "HTTP from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks=["0.0.0.0/0"]
  }
 tags = {
    Name = "sgtask"
  }
}

resource "aws_instance" "inst" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "keytask"
  security_groups = ["sgtask"]

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/DELL/OneDrive/Desktop/Terraform/terra2.pem")
    host     = aws_instance.inst.public_ip
  }
provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
 tags = {
    Name = "inst"
  }
 }

output "inst_ip" {
value = aws_instance.inst.public_ip
}


resource "null_resource" "local0"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.inst.public_ip} > publicip.txt"
  	}
}


resource "aws_ebs_volume" "taskvol" {
  availability_zone = aws_instance.inst.availability_zone
  size              = 1
 tags = {
    Name = "taskvol"
  }
}


resource "aws_volume_attachment" "vol_att" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.taskvol.id
  instance_id = aws_instance.inst.id
  force_detach = true
}


resource "null_resource" "remote2"  {

depends_on = [
    aws_volume_attachment.vol_att,
  ]
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/DELL/OneDrive/Desktop/Terraform/terra2.pem")
     host     = aws_instance.inst.public_ip
  }
provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdd",
      "sudo mount  /dev/xvdd  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/am1999/Task1HMC.git /var/www/html/"
    ]
  }
}



resource "aws_s3_bucket" "b" {
	bucket = "anki19"
	acl = "private"
    force_destroy = "true"
    versioning {
		enabled = true
	}
}




resource "null_resource" "local-1"  {
	depends_on = [aws_s3_bucket.b,]
	 provisioner "local-exec" {
      command = "git clone https://github.com/am1999/Task1HMC.git C:/Users/DELL/OneDrive/Desktop/Terraform/task1git"
}
}




resource "aws_s3_bucket_object" "fileupload" {
	depends_on = [aws_s3_bucket.b , null_resource.local-1]
	bucket = aws_s3_bucket.b.id
    key = "nature_hd.jpg"
	source = "C:/Users/DELL/OneDrive/Desktop/Terraform/task1git/nature_hd.jpg"
    acl = "public-read"
}

output "img" {
  value = aws_s3_bucket_object.fileupload
}






resource "aws_cloudfront_distribution" "distribution" {
	depends_on = [aws_s3_bucket.b , null_resource.local-1 ]
	origin {
		domain_name = aws_s3_bucket.b.bucket_regional_domain_name
		origin_id   = "S3-anki19-id"


		custom_origin_config {
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
		}
	}

	enabled = true

	default_cache_behavior {
		allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods = ["GET", "HEAD"]
		target_origin_id = "S3-anki19-id"

		forwarded_values {
			query_string = false

			cookies {
				forward = "none"
			}
		}
		viewer_protocol_policy = "allow-all"
		min_ttl = 0
		default_ttl = 3600
		max_ttl = 86400
	}

	restrictions {
		geo_restriction {

			restriction_type = "none"
		}
	}

	viewer_certificate {
		cloudfront_default_certificate = true
	}
}



output "domain-name" {
	value = aws_cloudfront_distribution.distribution.domain_name
}
