variables {
  vpc_id             = "vpc-123"
  ssh_keypair        = "test_keypair"
  subnet_ids         = ["subnet-1"]
  availability_zones = ["az-1"]
}

run "no CrateDB download URL" {
  command = plan

  variables {
    cratedb_tar_download_url = null
  }
}

run "valid CrateDB download URL" {
  command = plan

  variables {
    cratedb_tar_download_url = "https://cdn.crate.io/downloads/releases/cratedb/aarch64_linux/crate-5.5.1.tar.gz"
  }
}

run "invalid CrateDB download URL" {
  command = plan

  variables {
    cratedb_tar_download_url = "https://something_else.com/downloads/releases/cratedb/aarch64_linux/crate-5.5.1.tar.gz"
  }

  expect_failures = [var.cratedb_tar_download_url]
}

run "no CrateDB password" {
  command = plan

  variables {
    cratedb_password = null
  }
}

run "valid CrateDB password" {
  command = plan

  variables {
    cratedb_password = "zie6aeya9ooMeey0yai5"
  }
}

run "password with double dollar signs" {
  command = plan

  variables {
    cratedb_password = "ab$$cd"
  }

  expect_failures = [
    var.cratedb_password,
  ]
}
