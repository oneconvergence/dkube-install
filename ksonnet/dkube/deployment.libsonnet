{
    all(params):: [
	$.parts(params.namespace).logstash(params.tag, params.logstashImage, params.dkubeDockerSecret),
	$.parts(params.namespace).dkubeEtcd(params.tag),
	$.parts(params.namespace).dkubeD3api(params.tag, params.dkubeApiServerImage, params.dkubeApiServerAddr, params.dkubeMountPath, params.dkubeApiServerAddr, params.rdmaEnabled, params.dkubeDockerSecret, params.minioSecretKey),
	$.parts(params.namespace).dfabProxy(params.tag,params.dfabProxyImage, params.dkubeDockerSecret),
	$.parts(params.namespace).ambassdor(params.tag),
    ],

    parts(namespace):: {
        local ambassadorImage = "quay.io/datawire/ambassador:0.50.0",
	logstash(tag,logstashImage, dkubeDockerSecret):: {
	    "apiVersion": "apps/v1", 
	    "kind": "Deployment", 
	    "metadata": {
		"name": "logstash-" + tag, 
		"namespace": "dkube"
	    }, 
	    "spec": {
		"replicas": 1, 
		"selector": {
		    "matchLabels": {
			"app": "logstash"
		    }
		}, 
		"template": {
		    "metadata": {
			"labels": {
			    "app": "logstash"
			}
		    }, 
		    "spec": {
			"imagePullSecrets": [
			{
			    "name": dkubeDockerSecret
			}
			],
			"nodeSelector": {
				"d3.nodetype": "dkube"
			},
			"tolerations": [
				{
					"operator": "Exists"
				},
			],
			"containers": [
			{
			    "command": [
				"logstash",
			    "-f",
			    "config/logstash-sample.conf"
			    ], 
			    "image": logstashImage, 
			    "imagePullPolicy": "IfNotPresent", 
			    "name": "logstash"
			}
			],
            "dnsConfig": {
                "options": [
                    {
                        "name": "single-request-reopen"
                    },
                    {
                        "name": "timeout",
                        "value": "30"
                    }
                ]
            },
		    }
		}
	    }
	},
	dkubeEtcd(tag):: {
	    "apiVersion": "extensions/v1beta1",
	    "kind": "Deployment",
	    "metadata": {
		"name": "dkube-etcd-server-" + tag ,
		"namespace": "dkube"
	    },
	    "spec": {
		"selector": {
		    "matchLabels": {
			"app": "dkube-etcd-server"
		    }
		},
		"template": {
		    "metadata": {
			"labels": {
			    "app": "dkube-etcd-server"
			}
		    },
		    "spec": {
			"nodeSelector": {
				"d3.nodetype": "dkube"
			},
			"tolerations": [
				{
					"operator": "Exists"
				},
			],
			"containers": [
			{
			    "command": [
				"etcd",
			    "--listen-client-urls=http://0.0.0.0:2379",
			    "--advertise-client-urls=http://0.0.0.0:2379",
			    "--data-dir=/var/lib/etcd"
			    ],
			    "image": "k8s.gcr.io/etcd-amd64:3.1.12",
			    "imagePullPolicy": "IfNotPresent",
			    "name": "etcd",
			    "volumeMounts": [
			    {
				"mountPath": "/var/lib/etcd",
				"name": "etcd-data"
			    }
			    ]
			}
			],
            "dnsConfig": {
                "options": [
                    {
                        "name": "single-request-reopen"
                    },
                    {
                        "name": "timeout",
                        "value": "30"
                    }
                ]
            },
			"volumes": [
			{
			    "persistentVolumeClaim": {
				"claimName": "etcd-pvc"
			    },
			    "name": "etcd-data"
			}
			]
		    }
		}
	    }
	},

	dkubeD3api(tag, apiServerImage, apiServerAddr, mountPath, dkubeApiServerAddr, isRdmaEnabled, dkubeDockerSecret, minioSecretKey):: {
	    local dkubeApiServerAddrArray = std.split(dkubeApiServerAddr, ":"),
	    local dkubeApiServerPort = std.parseInt(dkubeApiServerAddrArray[std.length(dkubeApiServerAddrArray)-1]),

	    "apiVersion": "extensions/v1beta1", 
	    "kind": "Deployment", 
	    "metadata": {
		"labels": {
		    "app": "dkube-d3api"
		}, 
		"name": "dkube-d3api-" + tag , 
		"namespace": namespace
	    }, 
	    "spec": {
		"selector": {
		    "matchLabels": {
			"app": "dkube-d3api"
		    }
		}, 
		"template": {
		    "metadata": {
			"labels": {
			    "app": "dkube-d3api"
			}
		    }, 
		    "spec": {
			"imagePullSecrets": [
			{
			    "name": dkubeDockerSecret
			}
			],
			"nodeSelector": {
				"d3.nodetype": "dkube"
			},
			"tolerations": [
				{
					"operator": "Exists"
				},
			],
			"containers": [
			{
			    "image": apiServerImage, 
			    "imagePullPolicy": "IfNotPresent", 
			    "name": "dkube-d3api", 
			    "securityContext": {
				"runAsUser": 0
			    },
			    "ports": [
			    {
				"containerPort": dkubeApiServerPort, 
				"name": "dkube-d3api", 
				"protocol": "TCP"
			    }
			    ], 
			    "env": [
			    {
				"name": "DKUBE_MOUNT_PATH", 
				"value": mountPath
			    },
			    {
				"name": "DKUBE_SERVICE_ACCOUNT",
				"value": "dkube"
			    },
			    {
				"name": "RDMA_ENABLED",
				"value": std.toString(isRdmaEnabled)
			    }
			    ], 
			    "volumeMounts": [
			    {
				"mountPath": mountPath, 
				"name": "store"
			    },
			    {
				"mountPath": "/var/log/minio/dkube",
				"name": "dkube-logs"
			    },
				{
				"mountPath": "/var/log/dkube",
				"name": "dkube-logs-host"
				}
			    ]
			}
			], 
            "dnsConfig": {
                "options": [
                    {
                        "name": "single-request-reopen"
                    },
                    {
                        "name": "timeout",
                        "value": "30"
                    }
                ]
            },
			"serviceAccount": "dkube", 
			"volumes": [
			{
			    "flexVolume": {
				"driver": "oc/d3", 
				"options": {
				    "accessKey": "dkube", 
				    "bucket": "dkube", 
				    "endpoint": "http://127.0.0.1:32223",
				    "s3provider": "minio", 
				    "secretKey": minioSecretKey
				}
			    }, 
			    "name": "store"
			},
			{
			    "flexVolume": {
				"driver": "oc/d3", 
				"options": {
				    "accessKey": "dkube", 
				    "bucket": "logs", 
                    "prefix": "dkube",
				    "endpoint": "http://127.0.0.1:32223",
				    "s3provider": "minio", 
				    "secretKey": minioSecretKey
				}
			    }, 
			    "name": "dkube-logs"
			},
			{
				"hostPath": {
					"path": "/var/log/dkube",
					"type": "DirectoryOrCreate"
				},
				"name": "dkube-logs-host"
			}
			]
		    }
		}
	    }
	}, 

	dfabProxy(tag , dfabProxyImage, dkubeDockerSecret):: {
	    "apiVersion": "extensions/v1beta1",
	    "kind": "Deployment",
	    "metadata": {
		"labels": {
		    "app": "dfabproxy"
		},
		"name": "dfabproxy-" + tag ,
		"namespace": "dkube",
	    },
	    "spec": {
		"progressDeadlineSeconds": 600,
		"replicas": 1,
		"revisionHistoryLimit": 10,
		"selector": {
		    "matchLabels": {
			"app": "dfabproxy"
		    }
		},
		"strategy": {
		    "rollingUpdate": {
			"maxSurge": "25%",
			"maxUnavailable": "25%"
		    },
		    "type": "RollingUpdate"
		},
		"template": {
		    "metadata": {
			"creationTimestamp": null,
			"labels": {
			    "app": "dfabproxy"
			}
		    },
		    "spec": {
			"nodeSelector": {
				"d3.nodetype": "dkube"
			},
			"tolerations": [
				{
					"operator": "Exists"
				},
			],
			"containers": [
			{
			    "image": dfabProxyImage,
			    "imagePullPolicy": "IfNotPresent",
			    "name": "dfabproxy",
			    "resources": {},
			    "terminationMessagePath": "/dev/termination-log",
			    "terminationMessagePolicy": "File"
			}
			],
            "dnsConfig": {
                "options": [
                    {
                        "name": "single-request-reopen"
                    },
                    {
                        "name": "timeout",
                        "value": "30"
                    }
                ]
            },
			"dnsPolicy": "ClusterFirst",
			"imagePullSecrets": [
			{
			    "name": dkubeDockerSecret
			}
			],
			"restartPolicy": "Always",
			"schedulerName": "default-scheduler",
			"securityContext": {},
			"terminationGracePeriodSeconds": 30
		    }
		}
	    },
	},
      ambassdor(tag):: {
        apiVersion: "extensions/v1beta1",
        kind: "Deployment",
        metadata: {
          name: "ambassador-"+ tag ,
          namespace: namespace,
        },
        spec: {
          replicas: 1,
          template: {
            metadata: {
              labels: {
                service: "ambassador",
              },
              namespace: namespace,
            },
            spec: {
              "nodeSelector": {
                "d3.nodetype": "dkube"
              },
              "tolerations": [
                {
                  "operator": "Exists"
                },
              ],
              containers: [
                {
                  env: [
                    {
                      name: "AMBASSADOR_NAMESPACE",
                      valueFrom: {
                        fieldRef: {
                          fieldPath: "metadata.namespace",
                        },
                      },
                    },
                    {
                      name: "AMBASSADOR_SINGLE_NAMESPACE",
                      value: "false",
                    },
                  ],
                  image: ambassadorImage,
                  livenessProbe: {
                    httpGet: {
                      path: "/ambassador/v0/check_alive",
                      port: 8877,
                    },
                    initialDelaySeconds: 30,
                    periodSeconds: 30,
                  },
                  name: "ambassador",
                  readinessProbe: {
                    httpGet: {
                      path: "/ambassador/v0/check_ready",
                      port: 8877,
                    },
                    initialDelaySeconds: 30,
                    periodSeconds: 30,
                  },
                  resources: {
                    limits: {
                      cpu: 1,
                      memory: "400Mi",
                    },
                    requests: {
                      cpu: "200m",
                      memory: "100Mi",
                    },
                  },
                },
                //{
                //  image: "quay.io/datawire/statsd:0.30.1",
                //  name: "statsd",
                //},
              ],
            "dnsConfig": {
                "options": [
                    {
                        "name": "single-request-reopen"
                    },
                    {
                        "name": "timeout",
                        "value": "30"
                    }
                ]
            },
              restartPolicy: "Always",
              serviceAccountName: "ambassador",
             },
            },
          },
        }
    },
}
