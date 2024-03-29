variable "accept_limited_use_license" {
  description = "Acceptance of the SLULA terms (https://docs.snowplow.io/limited-use-license-1.0/)"
  type        = bool
  default     = false

  validation {
    condition     = var.accept_limited_use_license
    error_message = "Please accept the terms of the Snowplow Limited Use License Agreement to proceed."
  }
}

variable "name" {
  description = "A name which will be pre-pended to the resources created"
  type        = string
}

variable "app_version" {
  description = "App version to use. This variable facilitates dev flow, the modules may not work with anything other than the default value."
  type        = string
  default     = "2.1.2"
}

variable "vpc_id" {
  description = "The VPC to deploy the Elasticsearch Loader within"
  type        = string
}

variable "subnet_ids" {
  description = "The list of subnets to deploy the Elasticsearch Loader across"
  type        = list(string)
}

variable "instance_type" {
  description = "The instance type to use"
  type        = string
  default     = "t3a.micro"
}

variable "associate_public_ip_address" {
  description = "Whether to assign a public ip address to this instance"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "The name of the SSH key-pair to attach to all EC2 nodes deployed"
  type        = string
}

variable "ssh_ip_allowlist" {
  description = "The list of CIDR ranges to allow SSH traffic from"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "iam_permissions_boundary" {
  description = "The permissions boundary ARN to set on IAM roles created"
  default     = ""
  type        = string
}

variable "min_size" {
  description = "The minimum number of servers in this server-group"
  default     = 1
  type        = number
}

variable "max_size" {
  description = "The maximum number of servers in this server-group"
  default     = 2
  type        = number
}

variable "amazon_linux_2_ami_id" {
  description = "The AMI ID to use which must be based of of Amazon Linux 2; by default the latest community version is used"
  default     = ""
  type        = string
}

variable "kcl_read_min_capacity" {
  description = "The minimum READ capacity for the KCL DynamoDB table"
  type        = number
  default     = 1
}

variable "kcl_read_max_capacity" {
  description = "The maximum READ capacity for the KCL DynamoDB table"
  type        = number
  default     = 10
}

variable "kcl_write_min_capacity" {
  description = "The minimum WRITE capacity for the KCL DynamoDB table"
  type        = number
  default     = 1
}

variable "kcl_write_max_capacity" {
  description = "The maximum WRITE capacity for the KCL DynamoDB table"
  type        = number
  default     = 10
}

variable "tags" {
  description = "The tags to append to this resource"
  default     = {}
  type        = map(string)
}

variable "cloudwatch_logs_enabled" {
  description = "Whether application logs should be reported to CloudWatch"
  default     = true
  type        = bool
}

variable "cloudwatch_logs_retention_days" {
  description = "The length of time in days to retain logs for"
  default     = 7
  type        = number
}

variable "java_opts" {
  description = "Custom JAVA Options"
  default     = "-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75"
  type        = string
}

# --- Auto-scaling options

variable "enable_auto_scaling" {
  description = "Whether to enable auto-scaling policies for the service"
  default     = true
  type        = bool
}

variable "scale_up_cooldown_sec" {
  description = "Time (in seconds) until another scale-up action can occur"
  default     = 180
  type        = number
}

variable "scale_up_cpu_threshold_percentage" {
  description = "The average CPU percentage that must be exceeded to scale-up"
  default     = 60
  type        = number
}

variable "scale_up_eval_minutes" {
  description = "The number of consecutive minutes that the threshold must be breached to scale-up"
  default     = 5
  type        = number
}

variable "scale_down_cooldown_sec" {
  description = "Time (in seconds) until another scale-down action can occur"
  default     = 600
  type        = number
}

variable "scale_down_cpu_threshold_percentage" {
  description = "The average CPU percentage that we must be below to scale-down"
  default     = 20
  type        = number
}

variable "scale_down_eval_minutes" {
  description = "The number of consecutive minutes that we must be below the threshold to scale-down"
  default     = 60
  type        = number
}

# --- Configuration options

variable "in_stream_type" {
  description = "The type of data that will be consumed by the application (ENRICHED_EVENTS, BAD_ROWS or JSON)"
  type        = string
}

variable "in_stream_name" {
  description = "The name of the input kinesis stream that the Elasticsearch Loader will pull data from"
  type        = string
}

variable "bad_stream_name" {
  description = "The name of the bad kinesis stream that the Elasticsearch Loader will insert bad data into"
  type        = string
}

variable "initial_position" {
  description = "Where to start processing the input Kinesis Stream from (TRIM_HORIZON or LATEST)"
  default     = "TRIM_HORIZON"
  type        = string
}

variable "buffer_byte_limit" {
  description = "The amount of bytes to buffer events before pushing them to Elasticsearch"
  default     = 1000000
  type        = number
}

variable "buffer_record_limit" {
  description = "The number of events to buffer before pushing them to Elasticsearch"
  default     = 500
  type        = number
}

variable "buffer_time_limit_ms" {
  description = "The amount of time to buffer events before pushing them to Elasticsearch"
  default     = 500
  type        = number
}

variable "chunk_byte_limit" {
  description = "The maximum amount of bytes to send to Elasticsearch in one request"
  default     = 1000000
  type        = number
}

variable "chunk_record_limit" {
  description = "The maximum number of events to send to Elasticsearch in one request"
  default     = 500
  type        = number
}

variable "es_cluster_endpoint" {
  description = "The endpoint of the cluster to load data into"
  type        = string
}

variable "es_cluster_port" {
  description = "The port number of the cluster to load data into"
  type        = number
}

variable "es_cluster_username" {
  description = "A basicauth username to use when authenticating"
  type        = string
  default     = ""
}

variable "es_cluster_password" {
  description = "A basicauth password to use when authenticating"
  type        = string
  sensitive   = true
  default     = ""
}

variable "es_cluster_shard_date_format" {
  description = "A date format pattern for sharding inbound data into the cluster"
  type        = string
  default     = ""
}

variable "es_cluster_shard_date_field" {
  description = "The timestamp field to leverage when sharding data into the cluster (Note: defaults to derived_tstamp)"
  type        = string
  default     = ""
}

variable "es_cluster_http_ssl_enabled" {
  description = "Whether to enforce SSL for HTTP connections to the cluster"
  type        = bool
  default     = true
}

variable "es_cluster_index" {
  description = "The name of the Elasticsearch Index to load into"
  type        = string
}

variable "es_cluster_document_type" {
  description = "The document type of the data being loaded - this is the type defined in your index mapping (Note: generally 'good' or 'bad')"
  type        = string
  default     = ""
}

variable "aws_es_domain_name" {
  description = "The domain name of the Amazon Elasticsearch Service that signed requests will be made against"
  type        = string
  default     = ""
}

variable "aws_es_region" {
  description = "If signing is enabled this is the region where the destination cluster is located; if unset defaults to the region of the loader deployment"
  type        = string
  default     = ""
}

# --- Telemetry

variable "telemetry_enabled" {
  description = "Whether or not to send telemetry information back to Snowplow Analytics Ltd"
  type        = bool
  default     = true
}

variable "user_provided_id" {
  description = "An optional unique identifier to identify the telemetry events emitted by this stack"
  type        = string
  default     = ""
}
