from jinja2 import Environment, FileSystemLoader

file_loader = FileSystemLoader("templates")
env = Environment(
    loader=file_loader, trim_blocks=True, lstrip_blocks=True, keep_trailing_newline=True
)

files = [
    {
        "output": "docker/nginx/conf.dev",
        "config": {"proxy_frontend": True, "inside_docker": True},
    },
    {
        "output": "front/docker/funkwhale.conf.template",
        "config": {"proxy_frontend": False, "inside_docker": True},
    },
    {
        "output": "deploy/nginx.template",
        "config": {"proxy_frontend": False, "inside_docker": False},
    },
    {
        "output": "deploy/docker.proxy.template",
        "config": {
            "proxy_frontend": False,
            "inside_docker": False,
            "reverse_proxy": True,
        },
    },
]

template = env.get_template("nginx.conf.j2")
for f in files:
    print(f["output"])
    output = template.render(config=f["config"])

    output_file = open(f["output"], "w")
    output_file.write(output)
    output_file.close()
