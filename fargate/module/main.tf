# Create an ECR repository
resource "aws_ecr_repository" "repo" {
  name = var.suga.name
}

data "aws_ecr_authorization_token" "ecr_auth" {
}

data "docker_image" "latest" {
  name = var.suga.image_id
}

# Tag the provided docker image with the ECR repository url
resource "docker_tag" "tag" {
  source_image = length(data.docker_image.latest.repo_digest) > 0 ? data.docker_image.latest.repo_digest : data.docker_image.latest.id
  target_image = aws_ecr_repository.repo.repository_url
}

# Push the tagged image to the ECR repository
resource "docker_registry_image" "push" {
  name = aws_ecr_repository.repo.repository_url
  auth_config {
    address  = data.aws_ecr_authorization_token.ecr_auth.proxy_endpoint
    username = data.aws_ecr_authorization_token.ecr_auth.user_name
    password = data.aws_ecr_authorization_token.ecr_auth.password
  }
  triggers = {
    source_image_id = docker_tag.tag.source_image_id
  }
}

# Create IAM role for ECS task execution
resource "aws_iam_role" "task_execution_role" {
  name = "${var.suga.stack_id}-${var.suga.name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add ECR access policy
resource "aws_iam_role_policy" "task_execution_ecr_policy" {
  name = "${var.suga.stack_id}-${var.suga.name}-ecr"
  role = aws_iam_role.task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_lb" "alb" {
  arn = var.alb_arn
}

data "aws_region" "current" {
}

# Create a CloudWatch log group
resource "aws_cloudwatch_log_group" "default" {
  name = "${var.suga.stack_id}-${var.suga.name}"
}

# Create the task definition
resource "aws_ecs_task_definition" "service" {
  family                   = "${var.suga.stack_id}-${var.suga.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = var.suga.identities["aws:iam:role"].exports["aws_iam_role:arn"]
  container_definitions = jsonencode([
    {
      name      = "main"
      image     = "${aws_ecr_repository.repo.repository_url}@${docker_registry_image.push.sha256_digest}"
      cpu       = var.cpu
      memory    = var.memory
      essential = true

      environment = concat([
        {
          name = "CONTAINER_PORT"
          value = "${tostring(var.container_port)}"
        },
        {
          name = "SUGA_STACK_ID"
          value = var.suga.stack_id
        }
      ],
      [
        for k, v in var.environment : {
          name  = k
          value = "${tostring(v)}"
        }
      ],
      [
        for k, v in var.suga.env : {
          name  = k
          value = "${tostring(v)}"
        }
      ])

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.default.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = var.suga.name
        }
      }

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
    }
  ])
}

# Create a cluster definition for the service
resource "aws_ecs_cluster" "cluster" {
  name = "${var.suga.stack_id}-${var.suga.name}"
}

# Create an ESC service for the above task definition
resource "aws_ecs_service" "service" {
  name = "${var.suga.stack_id}-${var.suga.name}"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets = var.subnets
    security_groups = concat([var.alb_security_group], var.security_groups)
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = "main"
    container_port   = var.container_port
  }
}

# Create target group
resource "aws_lb_target_group" "service" {
  name        = "${var.suga.stack_id}-${var.suga.name}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  target_type = "ip"

  health_check {
    path = "/x-suga-health"
    interval = 30
    timeout = 10
    healthy_threshold = 2
  }
}

# Create listener
resource "aws_lb_listener" "service" {
  load_balancer_arn = var.alb_arn
  port              = var.container_port
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }
}

# # Setup ingress on the container port for the security groups
resource "aws_security_group_rule" "ingress" {
  security_group_id = var.alb_security_group
  self = true
  from_port = var.container_port
  to_port = var.container_port
  protocol = "tcp"
  type = "ingress"
}

