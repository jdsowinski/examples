# Anonymized pattern for building several ECS worker containers from a map.

locals {
  worker_definitions = {
    worker_one = {
      command_path = "workers/worker-one.js"
      count        = 1
    }
    worker_two = {
      command_path = "workers/worker-two.js"
      count        = 1
    }
  }

  worker_count = sum([
    for worker in values(local.worker_definitions) : worker.count
  ])

  worker_containers = flatten([
    for worker_key, worker in local.worker_definitions : [
      for index in range(worker.count) : {
        name              = "${worker_key}-${format("%02d", index + 1)}"
        image             = var.worker_image
        cpu               = floor(var.worker_task_cpu / local.worker_count)
        memory            = floor(var.worker_task_memory / local.worker_count)
        memoryReservation = floor(var.worker_task_memory / local.worker_count)
        essential         = true
        portMappings      = []
        command           = ["node", "dist/src/${worker.command_path}"]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-create-group  = "true"
            awslogs-group         = "/ecs/${local.service_family}-${worker_key}"
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "ecs"
          }
        }
        environment = local.environment_variables
        secrets     = local.secret_variables
      }
    ]
  ])
}
