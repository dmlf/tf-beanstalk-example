
terraform {
    backend "s3"{
        bucket  = "my-tfstates-bucket"
        key     = "folder/terraform.tfstate"
        region  = "eu-central-1"
        profile = "s3-profile" # ~/.aws/credentials [s3-profile]
    }
}

data "terraform_remote_state" "uat-env" {
    backend = "s3"
    config {
        bucket  = "my-tfstates-bucket"
        key     = "someotherfolder/terraform.tfstate"
        region  = "eu-central-1"
        profile = "s3-profile" # ~/.aws/credentials [s3-profile]
    }
}

resource "aws_elastic_beanstalk_application" "myapp" {
  name        = "myapp-webservice"
  description = "The app webservice"
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_elastic_beanstalk_environment" "myapp-uat-env" {
  name = "myapp-uat"
  application = "${aws_elastic_beanstalk_application.myapp.name}"
  solution_stack_name = "64bit Amazon Linux 2017.03 v2.6.0 running Multi-container Docker 1.12.6 (Generic)"
  cname_prefix = "myapp-uat"
  setting {
    namespace="aws:autoscaling:launchconfiguration"
    name="EC2KeyName"
    value="ingestion"
    }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = "arn:aws:iam::12345:instance-profile/IAM-XXX"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "VPCId"
    value = "${data.terraform_remote_state.uat-env.vpc_id}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "AssociatePublicIpAddress"
    value = "false"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "ELBSubnets"
    value = "${join(",", data.terraform_remote_state.uat-env.public_subnets_ids )}"
}
  setting {
    namespace = "aws:ec2:vpc"
    name = "Subnets"
    value = "${join(",", data.terraform_remote_state.uat-env.private_subnets_ids )}"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "ELBScheme"
    value = "external"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.nano"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "Availability Zones"
    value = "Any 2"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MinSize"
    value = "2"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MaxSize"
    value = "3"
  }
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name = "environment"
    value = "uat"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "RollingUpdateEnabled"
    value = "true"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "RollingUpdateType"
    value = "Health"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "MinInstancesInService"
    value = "2"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "MaxBatchSize"
    value = "1"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name = "CrossZone"
    value = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSizeType"
    value = "Fixed"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSize"
    value = "1"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "DeploymentPolicy"
    value = "Rolling"
  }
  setting {
    namespace = "aws:elb:policies"
    name = "ConnectionDrainingEnabled"
    value = "true"
  }
  setting {
    namespace="aws:elasticbeanstalk:application"
    name="Application Healthcheck URL"
    value="/healthcheck"
  }
  setting {
    namespace="aws:elb:listener:8080"
    name="ListenerProtocol"
    value="HTTP"
  }
  setting {
    namespace="aws:elb:listener:8080"
    name="InstancePort"
    value="80"
  }
}

data "aws_route53_zone" "myzone" {
  name         = "myzone.fqdn.."
  private_zone = false
}


resource "aws_route53_record" "myapp-uat-cname" {
  zone_id = "${data.aws_route53_zone.myzone.zone_id}"
  name    = "myapp-uat.eu-central-1"
  type    = "CNAME"
  ttl     = "300"

  records = [
    "${aws_elastic_beanstalk_environment.myapp-uat-env.cname}",
  ]
}

output "ws-fqdn" {
    value = "${aws_route53_record.myapp-uat-cname.fqdn}"
}
