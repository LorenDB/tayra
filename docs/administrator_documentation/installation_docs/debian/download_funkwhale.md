# 3. Download Funkwhale

Once you've created your `funkwhale` user you can download the Funkwhale software itself.

```{contents}
:local:
```

## Create the directory layout

1. Log in to your `funkwhale` account. This user works in the `/srv/funkwhale` directory.

   ```{code} bash
   su funkwhale
   ```

2. Create the directories for Funkwhale.

   ```{code} bash
   mkdir -p config api data/static data/media data/music front
   ```

That's it! Your directory structure should look like this:

```{code}
.
├── config      # config / environment files
├── api         # the Funkwhale API
├── data        # files served by the API
   └── static   # storage location for persistent data
   └── media    # storage location for media files
   └── music    # storage location for audio files   
└── front       # frontend files for the user interface
```

## Download the Funkwhale release

Once you've created the directory structure you can download Funkwhale. Funkwhale comes in two parts: the API and the Frontend. You need both to run the application.

1. Download the API.

   ```{code} bash
   curl -L -o "api-$FUNKWHALE_VERSION.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/$FUNKWHALE_VERSION/download?job=build_api"
   unzip "api-$FUNKWHALE_VERSION.zip" -d extracted 
   mv extracted/api/* api/ 
   rm -rf extracted rm api-$FUNKWHALE_VERSION.zip
   ```

2. Download the frontend

   ```{code} bash
   curl -L -o "front-$FUNKWHALE_VERSION.zip" "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/$FUNKWHALE_VERSION/download?job=build_front" 
   unzip "front-$FUNKWHALE_VERSION.zip" -d extracted 
   mv extracted/front . 
   rm -rf extracted
   rm front-$FUNKWHALE_VERSION.zip
   ```

You're done! These commands put the software in the correct location for Funkwhale to serve them.
