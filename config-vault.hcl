vault {
  address = "127.0.0.1:9200"

  auth {
    enabled = true
    username = "root"
    password = "root"
  }
}

log_level = "warn"

template {
  contents = "{{key \"hello\"}}"
  destination = "out.txt"
  exec {
    command = "cat out.txt"
  }
}