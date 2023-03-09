[![Release][release-image]][release] [![CI][ci-image]][ci] [![License][license-image]][license] [![Registry][registry-image]][registry] [![Source][source-image]][source]

# terraform-aws-elasticsearch-loader-kinesis-ec2

A Terraform module which deploys a Snowplow Elasticsearch Loader application on AWS running on top of EC2.  If you want to use a custom AMI for this deployment you will need to ensure it is based on top of Amazon Linux 2.

## Telemetry

This module by default collects and forwards telemetry information to Snowplow to understand how our applications are being used.  No identifying information about your sub-account or account fingerprints are ever forwarded to us - it is very simple information about what modules and applications are deployed and active.

If you wish to subscribe to our mailing list for updates to these modules or security advisories please set the `user_provided_id` variable to include a valid email address which we can reach you at.

### How do I disable it?

To disable telemetry simply set variable `telemetry_enabled = false`.

### What are you collecting?

For details on what information is collected please see this module: https://github.com/snowplow-devops/terraform-snowplow-telemetry

## Usage

### Cluster Authentication

There are two different ways to authenticate with the Elasticsearch Cluster - its important that you configure the loader appropriately to ensure that you can scope and connect to the destination cluster appropriately.

_Note_: If neither of these are defined its assumed that no authentication is required.

#### 1. AWS Elasticsearch Service + IAM and/or RBAC

The offerring from AWS supports RBAC and IAM based access controls.  As long as you have configured the `aws_es_domain_name` variable the loader will start signing all outbound requests.

You can then manage access via either a straightforward IAM policy at the cluster level which allows actions coming from the IAM role associated with the EC2 servers to insert data or take it a step forward and setup fine-grained-access-control with RBAC.  The later allows you to limit the loader to specific indices and patterns.

Documentation here: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/fgac.html

#### 2. Basic-auth

This one is pretty straight-forward - all you need to do is configure the `es_cluster_username` and `es_cluster_password` and then all HTTP requests sent from the loader will contain these variables as a basicauth header.

### How to manually configure the indices for data to load into?

Before loading data it is generally recommended to configure the index that you want to load into - this allows you to define the structure and expected types of the fields that are going to be loaded and avoids Elasticsearch interpreting a field incorrectly.

The default mappings for good (aka "enriched") and bad data can be found in the `templates/mappings` directory.

To then create an index it is as simple as issuing a single cURL command:

```bash
curl -XPUT \
  'https://${cluster_endpoint}/${index_name}?pretty' \
  -H 'Content-Type: application/json' \
  -d '${mapping_json}'"
```

This index name is what you would then configure for the loader in the `es_cluster_index` variable.

#### Do I need to set `es_cluster_document_type`?

The document type is a now deprecated field in an index mapping.  If you have an index created with a document type (`v6.x or earlier`) you should include this - if however you have created newer `v7.x` compatible indices you should not include this.  By default we set this to an empty string. 

#### How to rotate and manage manual indices?

_NOTE_: The loaders will infer mappings automatically - so this step is not required if you just want to quickly get started!

If you want to manage your index in the way detailed above you will need to rotate these indices as well.  Generally speaking indices are time-limited to allow you to expire data cleanly and to avoid having enormous indices to query across.

[Curator](https://curator.readthedocs.io/en/latest/index.html) is the general go to tool for dealing with this problem and Amazon has a fully worked example for how to set this up here: https://docs.aws.amazon.com/elasticsearch-service/latest/developerguide/curator.html

#### Using alias pointers to avoid updating the loader?

To avoid needing to update the loader configuration everytime you rotate the indices its recommended to leverage index aliases in front of these indexes and to use this alias name in the `es_cluster_index` variable.

Essentially the flow that needs to be followed is:

1. Create new index
2. Add this new index to the alias
3. Remove the old index from the alias

The loader should then begin loading into the new index automatically.

### Setting up the loader

This example shows the configuration for a fine-grained-access-control enabled Elasticsearch Service leveraging RBAC on the cluster to allow loading from EC2 nodes which have assumed the IAM role created by the loader module.

_Note_: Setting up the cluster "role" and linking it to the IAM role "user" are documented in the links above.

#### Loading good data

```hcl
locals {
  es_cluster_endpoint         = "vpc-xxx.eu-west-1.es.amazonaws.com"
  es_cluster_port             = 443
  es_cluster_http_ssl_enabled = true

  # Set if you want to use basicauth to authenticate
  #
  # Note: If using RBAC with AWS ES this should not be set as the authentication is done via the IAM role attached
  #       to the loader instances instead
  es_cluster_username = ""
  es_cluster_password = ""

  # Set if you want to use AWS Request Signing to authenticate
  #
  # Note: This requires configuring either an IAM cluster policy and/or fine-grained-access-control with the IAM role
  #       created by the ES Loader modules
  aws_es_domain_name = "test-cluster"

  # Set only if you are using a different region for your ES Cluster - by default will use the same region as the loader
  aws_es_region = ""
}

module "enriched_stream" {
  source  = "snowplow-devops/kinesis-stream/aws"
  version = "0.1.1"

  name = "enriched-stream"
}

module "bad_1_stream" {
  source  = "snowplow-devops/kinesis-stream/aws"
  version = "0.1.1"

  name = "bad-1-stream"
}

module "es_loader_enriched" {
  source  = "snowplow-devops/elasticsearch-loader-kinesis-ec2/aws"

  name             = "es-loader-enriched-server"
  vpc_id           = var.vpc_id
  subnet_ids       = var.subnet_ids
  ssh_key_name     = "your-key-name"
  ssh_ip_allowlist = ["0.0.0.0/0"]

  in_stream_type  = "ENRICHED_EVENTS"
  in_stream_name  = module.enriched_stream.name
  bad_stream_name = module.bad_1_stream.name

  es_cluster_endpoint         = local.es_cluster_endpoint
  es_cluster_port             = local.es_cluster_port
  es_cluster_http_ssl_enabled = local.es_cluster_http_ssl_enabled

  es_cluster_index         = "snowplow-enriched-index"
  es_cluster_document_type = "good"

  es_cluster_username = local.es_cluster_username
  es_cluster_password = local.es_cluster_password
  aws_es_domain_name  = local.aws_es_domain_name
  aws_es_region       = local.aws_es_region
}
```

#### Loading bad data

```hcl
module "bad_1_stream" {
  source  = "snowplow-devops/kinesis-stream/aws"
  version = "0.1.1"

  name = "bad-1-stream"
}

module "bad_2_stream" {
  source  = "snowplow-devops/kinesis-stream/aws"
  version = "0.1.1"

  name = "bad-2-stream"
}

module "es_loader_bad" {
  source  = "snowplow-devops/elasticsearch-loader-kinesis-ec2/aws"

  name             = "es-loader-bad-server"
  vpc_id           = var.vpc_id
  subnet_ids       = var.subnet_ids
  ssh_key_name     = "your-key-name"
  ssh_ip_allowlist = ["0.0.0.0/0"]

  in_stream_type  = "BAD_ROWS"
  in_stream_name  = module.bad_1_stream.name
  bad_stream_name = module.bad_2_stream.name

  es_cluster_endpoint         = local.es_cluster_endpoint
  es_cluster_port             = local.es_cluster_port
  es_cluster_http_ssl_enabled = local.es_cluster_http_ssl_enabled

  es_cluster_index         = "snowplow-bad-index"
  es_cluster_document_type = "bad"

  es_cluster_username = local.es_cluster_username
  es_cluster_password = local.es_cluster_password
  aws_es_domain_name  = local.aws_es_domain_name
  aws_es_region       = local.aws_es_region
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.75.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.75.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_instance_type_metrics"></a> [instance\_type\_metrics](#module\_instance\_type\_metrics) | snowplow-devops/ec2-instance-type-metrics/aws | 0.1.2 |
| <a name="module_kcl_autoscaling"></a> [kcl\_autoscaling](#module\_kcl\_autoscaling) | snowplow-devops/dynamodb-autoscaling/aws | 0.2.0 |
| <a name="module_service"></a> [service](#module\_service) | snowplow-devops/service-ec2/aws | 0.1.1 |
| <a name="module_telemetry"></a> [telemetry](#module\_telemetry) | snowplow-devops/telemetry/snowplow | 0.4.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.kcl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_instance_profile.instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.egress_tcp_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.egress_tcp_80](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.egress_tcp_es_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.egress_udp_123](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress_tcp_22](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bad_stream_name"></a> [bad\_stream\_name](#input\_bad\_stream\_name) | The name of the bad kinesis stream that the Elasticsearch Loader will insert bad data into | `string` | n/a | yes |
| <a name="input_es_cluster_endpoint"></a> [es\_cluster\_endpoint](#input\_es\_cluster\_endpoint) | The endpoint of the cluster to load data into | `string` | n/a | yes |
| <a name="input_es_cluster_index"></a> [es\_cluster\_index](#input\_es\_cluster\_index) | The name of the Elasticsearch Index to load into | `string` | n/a | yes |
| <a name="input_es_cluster_port"></a> [es\_cluster\_port](#input\_es\_cluster\_port) | The port number of the cluster to load data into | `number` | n/a | yes |
| <a name="input_in_stream_name"></a> [in\_stream\_name](#input\_in\_stream\_name) | The name of the input kinesis stream that the Elasticsearch Loader will pull data from | `string` | n/a | yes |
| <a name="input_in_stream_type"></a> [in\_stream\_type](#input\_in\_stream\_type) | The type of data that will be consumed by the application (ENRICHED\_EVENTS, BAD\_ROWS or JSON) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | A name which will be pre-pended to the resources created | `string` | n/a | yes |
| <a name="input_ssh_key_name"></a> [ssh\_key\_name](#input\_ssh\_key\_name) | The name of the SSH key-pair to attach to all EC2 nodes deployed | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The list of subnets to deploy the Elasticsearch Loader across | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC to deploy the Elasticsearch Loader within | `string` | n/a | yes |
| <a name="input_amazon_linux_2_ami_id"></a> [amazon\_linux\_2\_ami\_id](#input\_amazon\_linux\_2\_ami\_id) | The AMI ID to use which must be based of of Amazon Linux 2; by default the latest community version is used | `string` | `""` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether to assign a public ip address to this instance | `bool` | `true` | no |
| <a name="input_aws_es_domain_name"></a> [aws\_es\_domain\_name](#input\_aws\_es\_domain\_name) | The domain name of the Amazon Elasticsearch Service that signed requests will be made against | `string` | `""` | no |
| <a name="input_aws_es_region"></a> [aws\_es\_region](#input\_aws\_es\_region) | If signing is enabled this is the region where the destination cluster is located; if unset defaults to the region of the loader deployment | `string` | `""` | no |
| <a name="input_buffer_byte_limit"></a> [buffer\_byte\_limit](#input\_buffer\_byte\_limit) | The amount of bytes to buffer events before pushing them to Elasticsearch | `number` | `1000000` | no |
| <a name="input_buffer_record_limit"></a> [buffer\_record\_limit](#input\_buffer\_record\_limit) | The number of events to buffer before pushing them to Elasticsearch | `number` | `500` | no |
| <a name="input_buffer_time_limit_ms"></a> [buffer\_time\_limit\_ms](#input\_buffer\_time\_limit\_ms) | The amount of time to buffer events before pushing them to Elasticsearch | `number` | `500` | no |
| <a name="input_chunk_byte_limit"></a> [chunk\_byte\_limit](#input\_chunk\_byte\_limit) | The maximum amount of bytes to send to Elasticsearch in one request | `number` | `1000000` | no |
| <a name="input_chunk_record_limit"></a> [chunk\_record\_limit](#input\_chunk\_record\_limit) | The maximum number of events to send to Elasticsearch in one request | `number` | `500` | no |
| <a name="input_cloudwatch_logs_enabled"></a> [cloudwatch\_logs\_enabled](#input\_cloudwatch\_logs\_enabled) | Whether application logs should be reported to CloudWatch | `bool` | `true` | no |
| <a name="input_cloudwatch_logs_retention_days"></a> [cloudwatch\_logs\_retention\_days](#input\_cloudwatch\_logs\_retention\_days) | The length of time in days to retain logs for | `number` | `7` | no |
| <a name="input_enable_auto_scaling"></a> [enable\_auto\_scaling](#input\_enable\_auto\_scaling) | Whether to enable auto-scaling policies for the service | `bool` | `true` | no |
| <a name="input_es_cluster_document_type"></a> [es\_cluster\_document\_type](#input\_es\_cluster\_document\_type) | The document type of the data being loaded - this is the type defined in your index mapping (Note: generally 'good' or 'bad') | `string` | `""` | no |
| <a name="input_es_cluster_http_ssl_enabled"></a> [es\_cluster\_http\_ssl\_enabled](#input\_es\_cluster\_http\_ssl\_enabled) | Whether to enforce SSL for HTTP connections to the cluster | `bool` | `true` | no |
| <a name="input_es_cluster_password"></a> [es\_cluster\_password](#input\_es\_cluster\_password) | A basicauth password to use when authenticating | `string` | `""` | no |
| <a name="input_es_cluster_shard_date_field"></a> [es\_cluster\_shard\_date\_field](#input\_es\_cluster\_shard\_date\_field) | The timestamp field to leverage when sharding data into the cluster (Note: defaults to derived\_tstamp) | `string` | `""` | no |
| <a name="input_es_cluster_shard_date_format"></a> [es\_cluster\_shard\_date\_format](#input\_es\_cluster\_shard\_date\_format) | A date format pattern for sharding inbound data into the cluster | `string` | `""` | no |
| <a name="input_es_cluster_username"></a> [es\_cluster\_username](#input\_es\_cluster\_username) | A basicauth username to use when authenticating | `string` | `""` | no |
| <a name="input_iam_permissions_boundary"></a> [iam\_permissions\_boundary](#input\_iam\_permissions\_boundary) | The permissions boundary ARN to set on IAM roles created | `string` | `""` | no |
| <a name="input_initial_position"></a> [initial\_position](#input\_initial\_position) | Where to start processing the input Kinesis Stream from (TRIM\_HORIZON or LATEST) | `string` | `"TRIM_HORIZON"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The instance type to use | `string` | `"t3a.micro"` | no |
| <a name="input_java_opts"></a> [java\_opts](#input\_java\_opts) | Custom JAVA Options | `string` | `"-Dorg.slf4j.simpleLogger.defaultLogLevel=info -XX:MinRAMPercentage=50 -XX:MaxRAMPercentage=75"` | no |
| <a name="input_kcl_read_max_capacity"></a> [kcl\_read\_max\_capacity](#input\_kcl\_read\_max\_capacity) | The maximum READ capacity for the KCL DynamoDB table | `number` | `10` | no |
| <a name="input_kcl_read_min_capacity"></a> [kcl\_read\_min\_capacity](#input\_kcl\_read\_min\_capacity) | The minimum READ capacity for the KCL DynamoDB table | `number` | `1` | no |
| <a name="input_kcl_write_max_capacity"></a> [kcl\_write\_max\_capacity](#input\_kcl\_write\_max\_capacity) | The maximum WRITE capacity for the KCL DynamoDB table | `number` | `10` | no |
| <a name="input_kcl_write_min_capacity"></a> [kcl\_write\_min\_capacity](#input\_kcl\_write\_min\_capacity) | The minimum WRITE capacity for the KCL DynamoDB table | `number` | `1` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | The maximum number of servers in this server-group | `number` | `2` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | The minimum number of servers in this server-group | `number` | `1` | no |
| <a name="input_scale_down_cooldown_sec"></a> [scale\_down\_cooldown\_sec](#input\_scale\_down\_cooldown\_sec) | Time (in seconds) until another scale-down action can occur | `number` | `600` | no |
| <a name="input_scale_down_cpu_threshold_percentage"></a> [scale\_down\_cpu\_threshold\_percentage](#input\_scale\_down\_cpu\_threshold\_percentage) | The average CPU percentage that we must be below to scale-down | `number` | `20` | no |
| <a name="input_scale_down_eval_minutes"></a> [scale\_down\_eval\_minutes](#input\_scale\_down\_eval\_minutes) | The number of consecutive minutes that we must be below the threshold to scale-down | `number` | `60` | no |
| <a name="input_scale_up_cooldown_sec"></a> [scale\_up\_cooldown\_sec](#input\_scale\_up\_cooldown\_sec) | Time (in seconds) until another scale-up action can occur | `number` | `180` | no |
| <a name="input_scale_up_cpu_threshold_percentage"></a> [scale\_up\_cpu\_threshold\_percentage](#input\_scale\_up\_cpu\_threshold\_percentage) | The average CPU percentage that must be exceeded to scale-up | `number` | `60` | no |
| <a name="input_scale_up_eval_minutes"></a> [scale\_up\_eval\_minutes](#input\_scale\_up\_eval\_minutes) | The number of consecutive minutes that the threshold must be breached to scale-up | `number` | `5` | no |
| <a name="input_ssh_ip_allowlist"></a> [ssh\_ip\_allowlist](#input\_ssh\_ip\_allowlist) | The list of CIDR ranges to allow SSH traffic from | `list(any)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | The tags to append to this resource | `map(string)` | `{}` | no |
| <a name="input_telemetry_enabled"></a> [telemetry\_enabled](#input\_telemetry\_enabled) | Whether or not to send telemetry information back to Snowplow Analytics Ltd | `bool` | `true` | no |
| <a name="input_user_provided_id"></a> [user\_provided\_id](#input\_user\_provided\_id) | An optional unique identifier to identify the telemetry events emitted by this stack | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg_id"></a> [asg\_id](#output\_asg\_id) | ID of the ASG |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | Name of the ASG |
| <a name="output_sg_id"></a> [sg\_id](#output\_sg\_id) | ID of the security group attached to the Elasticsearch Loader servers |

# Copyright and license

The Terraform AWS Elasticsearch Loader on EC2 project is Copyright 2021-2022 Snowplow Analytics Ltd.

Licensed under the [Apache License, Version 2.0][license] (the "License");
you may not use this software except in compliance with the License.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

[release]: https://github.com/snowplow-devops/terraform-aws-elasticsearch-loader-kinesis-ec2/releases/latest
[release-image]: https://img.shields.io/github/v/release/snowplow-devops/terraform-aws-elasticsearch-loader-kinesis-ec2

[ci]: https://github.com/snowplow-devops/terraform-aws-elasticsearch-loader-kinesis-ec2/actions?query=workflow%3Aci
[ci-image]: https://github.com/snowplow-devops/terraform-aws-elasticsearch-loader-kinesis-ec2/workflows/ci/badge.svg

[license]: https://www.apache.org/licenses/LICENSE-2.0
[license-image]: https://img.shields.io/badge/license-Apache--2-blue.svg?style=flat

[registry]: https://registry.terraform.io/modules/snowplow-devops/elasticsearch-loader-kinesis-ec2/aws/latest
[registry-image]: https://img.shields.io/static/v1?label=Terraform&message=Registry&color=7B42BC&logo=terraform

[source]: https://github.com/snowplow/snowplow-elasticsearch-loader
[source-image]: https://img.shields.io/static/v1?label=Snowplow&message=Elasticsearch%20Loader&color=0E9BA4&logo=GitHub
