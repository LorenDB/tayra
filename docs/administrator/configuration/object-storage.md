# Store media in an object store

By default, Funkwhale stores all media data in the `/srv/funkwhale/data/media` directory. If you prefer to use an S3-compatible object store, follow the instructions in this guide.

```{contents}
:local:
:depth: 1
```

## Secure your object store

Before you begin, you need to secure your object store. Many S3-compatible stores list contents in the root by default. This exposes the URLs of your audio files and means that users can bypass authentication.

To prevent listing content, add the following policy to your S3-compatible object store.

```{code-block} json
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Action": [
            "s3:GetObject"
        ],
        "Effect": "Allow",
        "Principal": {
            "AWS": [
            "*"
            ]
        },
        "Resource": [
            "arn:aws:s3:::<yourbucketname>/*"
        ],
        "Sid": "Public"
        }
    ]
}
```

If you're using `awscli`, you can store this policy in a `/tmp/policy` file and apply it using the following command:

```{code-block} sh
aws s3api put-bucket-policy --bucket <yourbucketname> --policy file:///tmp/policy
```

## Update your environment file

To set up S3-compatible storage, fill out the relevant details in the `.env` file. If you want to serve audio files from the bucket, set `PROXY_MEDIA` to `false`.

:::{dropdown} Environment variables

```{eval-rst}

.. autodata:: config.settings.common.AWS_QUERYSTRING_AUTH
   :noindex:
.. autodata:: config.settings.common.AWS_QUERYSTRING_EXPIRE
   :noindex:
.. autodata:: config.settings.common.AWS_ACCESS_KEY_ID
   :noindex:
.. autodata:: config.settings.common.AWS_SECRET_ACCESS_KEY
   :noindex:
.. autodata:: config.settings.common.AWS_STORAGE_BUCKET_NAME
   :noindex:
.. autodata:: config.settings.common.AWS_S3_CUSTOM_DOMAIN
   :noindex:
.. autodata:: config.settings.common.AWS_S3_ENDPOINT_URL
   :noindex:
   :annotation: = https://minio.mydomain.com
.. autodata:: config.settings.common.AWS_S3_REGION_NAME
   :noindex:
   :annotation: = eu-west-2
.. autodata:: config.settings.common.AWS_LOCATION
   :noindex:
   :annotation: = funkwhale_music
.. autodata:: config.settings.common.PROXY_MEDIA
   :noindex:

```

:::

## Set up your reverse proxy

```{note}
Serving files from object storage is not currently supported on Apache deployments.
```

Serving files from an object store requires some changes to the reverse proxy.

1. Open your Nginx configuration file in an editor.

   ::::{tab-set}

   :::{tab-item} Debian
   :sync: debian

   ```{code-block} sh
   sudo nano /etc/nginx/sites-available/funkwhale.template
   ```

   :::

   :::{tab-item} Docker
   :sync: docker

   ```{code-block} sh
   nano /srv/funkwhale/nginx/funkwhale.template
   ```

   :::
   ::::

2. Comment out the `location /_protected/media/` block by adding a `#` to the start of each line.

   ```{code-block} text
   #   location /_protected/media/ {
   #        internal;
   #        alias   ${MEDIA_ROOT};
   #    }
   ```

3. Uncomment the `location ~ /_protected/media/(.+)` block by removing the `#` from the start of each line.

   ```{code-block} text
      location ~ /_protected/media/(.+) {
            internal;
            proxy_set_header Authorization "";
            proxy_pass $1;
      }
   ```

4. Add your S3 store URL to the `img-src` and `media-src` headers.

   ```{code-block} text
   add_header Content-Security-Policy "...img-src 'self' https://<your-s3-URL> data:;...media-src https://<your-s3-URL> 'self' data:";
   ```

5. Test your Nginx configuration.

   ```{code-block} sh
   sudo nginx -t
   ```

6. Restart Funkwhale and Nginx to pick up the changes.

   ::::{tab-set}

   :::{tab-item} Debian
   :sync: debian

   ```{code-block} sh
   sudo systemctl restart funkwhale.target
   sudo systemctl restart nginx
   ```

   :::

   :::{tab-item} Docker
   :sync: docker

   ```{code-block} sh
   sudo docker compose restart
   sudo systemctl restart nginx
   ```

   :::
   ::::

That's it! Files are now uploaded to and stored from your S3 bucket.

## Troubleshooting

:::{dropdown} No Resolver Found

You may see the following error when streaming music from your S3-compatible store:

```{code-block} text
[error] 2832#2832: *1 no resolver defined to resolve [address] client: [IP], server: [servername], request: "GET API request", host: "[your_domain]", referrer: "[your_domain/library]"
```

This happens when the Nginx config is unable to use your server’s DNS resolver. We're still looking into this issue. You can work around this by adding a resolver to the `location ~/_protected/media/(.+)` block.

```{code-block} text
location ~ /_protected/media/(.+) {
    resolver 1.1.1.1;
    internal;
    proxy_set_header Authorization "";
    proxy_pass $1;
}
```

:::
