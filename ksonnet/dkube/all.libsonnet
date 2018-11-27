{
  parts(params):: {
    local ambassador = import "dkube/dkube/ambassador.libsonnet",
    local dkube = import "dkube/dkube/dkube.libsonnet",
    local logstash = import "dkube/dkube/logstash.libsonnet",
    local etcd = import "dkube/dkube/etcd.libsonnet",

    all:: dkube.all(params)
          + ambassador.all(params)
          + logstash.all(params)
          + etcd.all(params)
  },
}