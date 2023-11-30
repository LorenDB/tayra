# Changelog

You can subscribe to release announcements by:

- Following [@funkwhale@fosstodon.org](https://fosstodon.org/@funkwhale) on Mastodon
- Subscribing to the following Atom feed: https://dev.funkwhale.audio/funkwhale/funkwhale/commits/develop?format=atom&search=Merge+tag

This changelog is viewable on the web at https://docs.funkwhale.audio/changelog.html.

<!-- towncrier -->

## 1.4.0-rc2 (2023-11-30)

Upgrade instructions are available at https://docs.funkwhale.audio/administrator/upgrade/index.html

Changes since 1.4.0-rc1:

Bugfixes:

- Fix broken nginx templates for docker setup (#2252)
- Fix docker builds in CI by using correct flag to disable cache

## 1.4.0-rc1 (2023-11-28)

Upgrade instructions are available at https://docs.funkwhale.audio/administrator/upgrade/index.html

Features:

- Add atom1.0 to node info services (#2085)
- Add basic cypress testing
- Add NodeInfo 2.1 (#2085)
- Add support for Funkwhale UI library.
- Add support for Python 3.12
- Allow moderators to set moderation languages (#2085)
- Allow to set the instances server location (#2085)
- Cache radio queryset into redis. New radio track endpoint for api v2 is /api/v2/radios/sessions/{radiosessionid}/tracks (#2135)
- Create a testing environment in production for ListenBrainz recommendation engine (troi-recommendation-playground) (#1861)
- Generate all nginx configurations from one template
- New management command to update Uploads which have been imported using --in-place and are now stored in s3 (#2156)
- Add option to only allow MusicBrainz tagged file on a pod (#2083)
- Prohibit the creation of new users using django's `createsuperuser` command in favor of our own CLI
  entry point. Run `funkwhale-manage fw users create --superuser` instead. (#1288)

Enhancements:

- Add a management command to generate dummy notifications for testing
- Add custom logging functionality (#2155)
- Adding typesense container and api client (2104)
- Cache pip package in api docker builds (#2193)
- Connect loglevel and debug mode (#1538)
- Get api version from python package
- Log service worker registration error and add a warning about Firefox SW incompatibility in development mode
- Maintain api version using poetry
- Maloja: Submit album artists and duration and allow to disable server side metadata fixing
- Replace pytz with zoneinfo in the API
- Speed up linting and type-checking by using cache
- Split front large bundles into smaller chunks
- Support boolean config fields in plugins

Bugfixes:

- `postgres > db_dump.sql` cannot be used if the postgres container is stopped. Update command.
- Avoid troi radio to give duplicates (#2231)
- Fix help messages for running scripts using funkwhale-manage
- Fix missing og meta tags (#2208)
- Fix multiarch docker builds #2211
- Fixed an issue where the copy button didn't copy the Embed code in the embed modal.
- Fixed an issue with the nginx templates that caused issues when connecting to websockets.
- Fixed development docker setup (2102)
- Fixed development docker setup (2196)
- Fixed embedded player crash when API returns relative listen URL. (#2163)
- Fixed issue with regular expression in embed.
- Make Artist ordering by name case insensitive
- Make sure build requirements for ujson are met
- Make sure embed codes generated before 1.3.0 are still working
- Make sure funkwhale_api package and metadata are available for docs
- Make sure meta tags link to embedded player correctly
- Merge nginx configs for docker production and development setups (#1939)
- Updated links to the Funkwhale website in the UI. (#2235)
- Use correct data field for rate limiting identity field (#2248)

Documentation:

- Add missing `has_mbid` requirement to quality filter spec.
- Add spec for user following.
- Added CoC link to nodeinfo endpoint spec.
- Added multi-artist support spec.
- Added new collections spec.
- Added NodeInfo 2.1 specification
- Archived the pre-1.0 changelog
- Updated nodeinfo spec to include usage statistics.
- Updated the Nodeinfo 2 spec to address feedback from implementation.

Other:

- Add build metadata script
- Don't run CI on branch containing stable or develop
- Fix CI deploy docs job after stable branch merge
- Format api container file
- Lint api code using pylint
- Make renovate not pinning the python version to the latest one
- Rename CHANGELOG to CHANGELOG.md
- Replace docs scripts with make
- Rework the CI pipeline
- Use buildx bake in docker job

Removal:

- Drop support for python3.7

## 1.3.4 (2023-11-16)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Remove dangling dependency howler

Documentation:

- Fix a redirect loop on documentation for moderators

Contributors to our Merge Requests:

- Georg Krause
- Thomas

Committers:

- Georg Krause

## 1.3.3 (2023-09-07)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Revert changed logging to fix crashes

Contributors to our Issues:

- Alexandra Parker
- Aurelien Vaillant
- ChengChung
- Ciarán Ainsworth
- Georg Krause
- Johann Queuniet
- Kasper Seweryn
- Mathieu Jourdan
- Nicolas Derive
- Puniko Nyan
- Thomas
- petitminion
- philip ballinger

Contributors to our Merge Requests:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Marcos Peña
- jooola
- petitminion

## 1.3.2 (2023-09-01)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Enable sourcemaps for production builds
- Use logger composable instead of window.console

Bugfixes:

- Clear shuffled id list on queue clear (#2192)
- Fetch the nodeinfo endpoint from .well-known/nodeinfo when checking instance availability
- Fix instance checking its own availability (#2199)
- Fix multiarch docker builds #2211
- Fix ordering when querystring contains `+` prefix
  Resolve multiple updates to ordering fields
- Fix password reset via email
- Make podcast episode pagination reactive (#2205)
- Render HTML in podcast short description (#2206)
- Resolve race condition regarding axios when initializing the frontend
  Prevent sending same language setting to backend multiple times

Documentation:

- Fixed incorrect upgrade instructions link in docs.

Contributors to our Issues:

- Ciarán Ainsworth
- Georg Krause
- Kasper Seweryn
- Kay Borowski
- Marcos Peña
- Mathieu Jourdan
- Virgile Robles
- codl
- jooola
- petitminion
- tinglycraniumplacidly
- unkn0wwn52

Contributors to our Merge Requests:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Marcos Peña
- Virgile Robles
- codl
- jooola
- petitminion

Committers:

- Ciarán Ainsworth
- codl
- Georg Krause
- jo
- Kasper Seweryn
- petitminion

## 1.3.1 (2023-06-27)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Dynamically add report targets to the map to avoid missing keys (#2121)
- Fix location of the nginx config template for docker deployments (#2146)
- Fix pagination on search page (#2134)
- Fix Prune skipped uploads is OOM killed (#2136)
- Fixed Fomantic UI dropdown messing with Vue internals in radio builder (#2142)
- Fixed premature login redirect on podcast detail page (#2155)
- Fixed stale data in indexedDB after logout (#2133)
- Make sure dependency pins are working with pip install (Restores python3.7 support)
- Make sure embed codes generated before 1.3.0 are still working
- Make sure the SPA Manifest is fetched using the right protocol (#2151)
- Moved modals above all content (#2154)
- Raise SystemExit exception in API manage.py script
- Remove track from cache when it gets disposed outside of the cache handler (#2157)
- Standardize instanceUrl value in instance store (#2113)
- Fix for banner images not being served on pods.
- Fixed PWA Window theme color.

Documentation:

- Fix instructions for using custom nginx configurations in our documentation

Other:

- Don't run CI on branch containing stable or develop

Contributors to our Issues:

- AMoonRabbit
- Asier Iturralde Sarasola
- Bertille D.
- Casuallynoted
- Ciarán Ainsworth
- Daniel Jeller
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Mathieu Jourdan
- NaiveTub
- Ricardo
- Virgile Robles
- nouts
- petitminion

Contributors to our Merge Requests:

- AMoonRabbit
- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- jooola
- petitminion

Committers:

- AMoonRabbit
- Georg Krause
- jo
- JuniorJPDJ
- Kasper Seweryn
- Moon Rabbit
- Petitminion

## 1.3.0 (2023-06-01)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Update instructions:

- If you are running the docker deployment, make sure to update our compose file.
  In this small example we show you how to save the old config and update it
  correctly:

  ```
  export FUNKWHALE_VERSION="1.3.0"
  cd /srv/funkwhale
  docker-compose down
  mv docker-compose.yml docker-compose.bak
  curl -L -o /srv/funkwhale/docker-compose.yml "https://dev.funkwhale.audio/funkwhale/funkwhale/raw/${FUNKWHALE_VERSION}/deploy/docker-compose.yml"
  ```

  :::{note}
  If you need to customize your nginx template, e.g. to work around [problems with Docker's resolver](https://docs.funkwhale.audio/admin/external-storages.html#no-resolver-found), you can mount your
  custom nginx configuration into the container. Uncomment the commented volumes in the `nginx` section of your `docker-compose.yml`.
  Additionally you need to update the paths in `nginx/funkwhale.template`.
  Replace all occurrences of `/funkwhale` by `/usr/share/nginx/html`.
  This loads the templates from your `nginx` folder and overrides the template files in the Docker container.
  :::

  ```
  docker-compose up -d
  ```

- The Docker instructions now use the updated Docker compose plugin. If you previously used the `docker-compose` standalone installation, do the following while upgrading:

  1. Download the [Docker compose plugin](https://docs.docker.com/compose/install/linux/#install-using-the-repository)
  2. Stop your containers using the **docker-compose** syntax.

  ```sh
  sudo docker-compose down
  ```

  3. Bring the containers back up using the **docker compose** syntax.

  ```sh
  sudo docker compose up -d
  ```

  After this you can continue to use the **docker compose** syntax for all Docker management tasks.

- Upgrade Postgres to version 15. [Make sure to migrate!](https://docs.funkwhale.audio/administrator/upgrade/docker.html#upgrade-the-postgres-container)
- With this update Funkwhale starts using poetry to maintain its dependencies. We therefore recommend
  removing the old virtualenv by running `rm -rf /srv/funkwhale/virtualenv`.

Features:

- Add a management command to create a new library for a user
- Add Gitpod configuration and guide
- Add Sentry SDK to collect #1479
- Prepare API for the upcoming version 2
- Rewrite player to be based on Web Audio API

Enhancements:

- Add a celery task to scan remote library (#1712)
- Add coverage report for Frontend Tests
- Add hint which serializer is used for OembedView (#1901)
- Add music visualizer (#1135)
- Add playable tracks to gitpod instance
- Add playlists radio to search page (#1968)
- Add proper serialization for TextPreviewView (#1903)
- Add python debug and test support for gitpod
- Add Serializer for SpaManifest endpoint
- Add support for python 3.11
- Added proper serializers for the rate-limit endpoint.
- Added type hints to the API.
- Adding support for play all radio in search result page (#1563)
- All administrator documentation has been rewritten to improve clarity and update outdated information.
- Allow arbitrary length names for artists, albums and tracks
- Allow installing the funkwhale_api package
- Allow using default browser dark mode and update UI dynamically on change
- Apply migrations on API container start (!1879)
- Automatically fetch next page of tracks (#1526)
- Build frontend natively for cross-arch docker images
- Change unmaintained PyMemoize library to django-cache-memoize
  to enable Python 3.10 support
- Cleaned up frontend docker container
- Cleanup Gitlab CI and Dockerfiles (!1796)
- Create the funkwhale-manage entrypoint in the api package
- Created migration guide for the deprecated all-in-one docker container.
- Don't buffer python stdout/err in docker
- Don't compile python byte code in docker
- Don't use poetry in production deployments
- Drop direct dependency on pyopenssl (#1975)
- Exclude /api/v1/oauth/authorize from the specs since its not supported yet (#1899)
- Fix openapi specs for user endpoints (#1892, #1894)
- Fix Serializer for inline channel artists (#1833)
- Fix specs for ListenViewSet (#1898)
- Handle PWA correctly and provide better cache strategy for album covers (#1721)
- Improve docker caching
- Improve specification of LibraryFollowViewSet (#1896)
- Install API python package in docker image
- Make CI always run all tests on protected branches.
- Make mutations endpoint appear in openapi specs
- Make Python 3.10 tests in CI mandatory
- Make sure ChannelViewSet always has a serializer (#1895)
- Migrate to new queue system from old localStorage keys
- Migrate to Vue 3
- Migrate to vue-i18n (#1831)
  Fix locale changing (#1862)
- Migrated to sphinx-design.
- New task checking if remote instance is reachable to avoid playback latence (#1711)
- OAuth Application client secrets are now hashed before storing them to the DB. Those are only displayed once from now on!
- Parameterize the default S3 ACL when uploading objects. (#1319)
- Pin Alpine package versions in API Dockerfile (fixes part of CI build issues).
- Prefer using the funkwhale-manage entrypoint
- Prevent running two pipelines for MRs
- Random and less listened radio filter out un-owned content on library section (#2007)
- Refactor node info endpoint to use proper serializers
- Refactor SettingsView to use a proper serializer
- Remove unnecessary or wrong `is` keyword usage from backend
- Rename OpenAPI schema's operation ids for nicer API client method names.
- Replace django-channels package with web socket implementation from @vueuse/core (#1715)
- Retry fetching new radio track 5 times if error occurred before resetting radio session (#2022)
- Rewrite embedded player to petite-vue
- Split DATABASE_URL into multiple configuration variables
- The ListenBrainz plugin submits the track duration
- Update Django OAuth Toolkit to version 2, ref #1944
- Update migration after django update (#1815)
- Update upload status when import fails (#1999)
- Updated the installation guides to make installation steps clearer.
- Upgrade docker base image to alpine 3.17
- Use proper serializer for Search endpoint (#1902)

Refactoring:

- Instead of requesting the right spa content from the API using a middleware we now serve the
  Frontend directly with nginx and only proxy-forward for API endpoints
- Replace django-rest-auth with dj-rest-auth (#1877)

Bugfixes:

- Allow enabling systemd funkwhale.target
- Allow playback of media from external frontend (#1937).
- Allow summary field of actors to be blank. This leaves actors valid that have a blank (`""`) summary field and allows follows from those.
- Catch ValueError on radio end (#1596)
- Channel overview was displaying foreign tracks (#1773) (1773)
- Docker setup: do not export the API port 5000 publicly
- Fix adding same track multiple times (#1933)
- Fix artist name submission in Maloja plugin
- Fix changing visualizer CORS error (#1934).
- Fix content form autofocus despite `autofocus` prop being set to `false` (#1924)
- Fix CSP header issues
- Fix CSP issue caused by django-channels package (#1752)
- Fix docker API image building with removing autobahn workaround version pin
- Fix docker builds on armv7
- Fix docker nginx entrypoint
- Fix editing playlist tracks (#1362)
- Fix embedded player not working on social posts (1946)
- Fix favorite button in queue
- Fix fetching pages of albums in album detail view (#1927)
- Fix front album tracks count translation
- Fix global keyboard shortcuts firing when input is focused (#1876)
- Fix lots of problems in debian installation guide
- Fix media directory nginx routing error in front docker container introduced in !1897
- Fix OAuth login (#1890)
- Fix play button in albums with multi-page volumes (#1928)
- Fix player closing when queue ends (#1931)
- Fix postgres connection details in docker setup
- Fix purging of dangling files #1929
- Fix remote search (#1857)
- Fix search by text in affected views (#1858)
- Fix timeout on spa manifest requests
- Fix track table showing all tracks and double pagination in some cases (#1923)
- Fix user requests and reports filtering (#1924)
- Fix validity issues in openapi/swagger spec files (#1171)
- Fixed an issue which caused links in Markdown forms to not render correctly. (#2023)
- Fixed login redirect (1736)
- Fixed mobile player element widths (#2054)
- Fixed remote subscription form in Podcast and search views (#1708)
- Fixed upload form VUE errors (#1738) (1738)
- Fixes an issue which made it possible to download all media files without access control (#2101)
- Fixes channel page (#1729) (1729)
- Fixes development environment set-up with docker (1726)
- Fixes embed player (#1783) (1783)
- Fixes service worker (#1634)
- Fixes track listenings not being sent when tab is not focused
- Hide create custom radio to un-authenticated users (#1720)
- Improve signal handling for service and containers
- Move api docker hardcoded env vars in the settings module
- Prefer str over dict for the CACHE_URL api setting

  This fix the ability to reuse the CACHE_URL with other settings such as
  CELERY_BROKER_URL.

- Remove trailing slash from reverse proxy configuration
- Remove unused Footer component (#1660)
- Remove usage of deprecated Model and Serializer fields (#1663)
- Resolved an issue where queue text with mouse over has dark text on dark background (#2058) (2058)
- Skip refreshing local actors in celery federation.refresh_actor_data task - fixes disappearing avatars (!1873)

Documentation:

- Add ability to translate documentation into multiple languages
- Add generic upgrade instructions to Docker postgres documentation (#2049)
- Add restore instructions to backup docs (#1627).
- Add systemd update instructions to Debian upgrade instructions (#1966)
- Added Nginx regeneration instructions to Debian update guide (#2050)
- Added virtualenv upgrade instructions for Debian (#1562).
- Cleaned up documentation
- Document the new login flow of the CLI-tool (#1800)
- Documented LOGLEVEL command (#1541).
- Documented the `NGINX_MAX_BODY_SIZE` .env variable (#1624).
- Fix broken links in CHANGELOG (#1976)
- Harden security for debian install docs
- Remove unnecessary postgres variable in Docker migration guide (#2124).
- Rewrote documentation contributor guide.
- Rewrote the architecture file (#1908)
- Rewrote the federation developer documentation (#1911)
- Rewrote the plugins documentation (#1910)
- Rewrote translators file
- Updated API developer documentation (#1912, #1909)
- Updated CONTRIBUTING guide with up-to-date documentation. Created layout in documentation hub.

Other:

- Add a CI job to check if changelog snippet is available
- Add CI broken links checker
- Add pre-commit hooks
  - flake8
  - black
  - isort
  - pyupgrade
  - prettier
  - codespell
- Add pre-commit to development tools
- Align the openapi spec to the actual API wherever possible
- Cache lychee checked urls for 1 day in CI
- Fix api tests warnings by renaming fixtures
- Fix permissions for build artifacts
- Fix shell scripts lint errors
- Format api pyproject.toml
- Format or fix files using pre-commit

  - Upgrade code to >=python3.7
  - Fix flake8 warnings
  - Fix spelling errors
  - Format files using black
  - Format files using isort
  - Format files using prettier

- Move api tools config to pyproject.toml
- Move database url composition from custom script to django settings
- Remove docker_all_in_one_release ci job
- Rename api composer/django/ dir to docker/
- Unpin asgiref in API dependencies
- Use vite for building the frontend, #1644

Deprecation:

- Deprecate the api manage.py script in favor of the funkwhale-manage entrypoint
- That's the last minor version series that supports python3.7. Funkwhale 1.4 will remove support for
  it. #1693
- The automatically generated `DATABASE_URL` configuration in the docker setup is deprecated, please
  configure either the `DATABASE_URL` environment variable or the `DATABASE_HOST`, `DATABASE_USER` and
  `DATABASE_PASSWORD` environment variables instead.

Removal:

- This release removes support for Python 3.6. Please make sure you update your python version before
  Updating Funkwhale!

Committers:

- Agate
- Aina Hernàndez Campaña
- AMoonRabbit
- Anton
- bruce diao
- Bruno Talanski
- ButterflyOfFire
- Çağla Pickaxe
- Ciarán Ainsworth
- Dignified Silence
- dignny
- Éilias McTalún
- EorlBruder
- Fedi Funkers
- Georg Krause
- ghose
- Henri Dickson
- Jacek Pruciak
- Jasper Bogers
- Jhoan Sebastian Espinosa Borrero
- jo
- jooola
- Julian Rademacher
- JuniorJPDJ
- Kasper Seweryn
- Keunes
- Kisel1337
- Laurin W
- Marcos Peña
- Matyáš Caras
- Michael Long
- nztvar
- oki
- Petitminion
- Philipp Wolfer
- poeppe
- Porrumentzio
- ppom
- Reinhard Prechtl
- Sky
- Sporiff
- Stuart Begley-Miller
- @ta
- Thomas
- Till Robin Zickel
- tobifroe
- wvffle

Contributors to our Issues:

- AMoonRabbit
- Agate
- Artem Anufrij
- ChengChung
- Ciarán Ainsworth
- Creak
- Eric Mesa
- Georg Krause
- Hans Bauer
- HurricaneDancer
- Jakob Schürz
- Jucgshu
- Julian-Samuel Gebühr
- JuniorJPDJ
- Kasper Seweryn
- Keunes
- Laser Lesbian
- Laurin W
- Marco
- Marcos Peña
- Martin Giger
- Mathieu Jourdan
- MattDHarding
- Meliurwen
- Micha Gläß-Stöcker
- MichaelBechHansen
- Nathan Mih
- Nicolas Derive
- Nolan Darilek
- Philipp Wolfer
- Porrumentzio
- Rodion Borisov
- Sam Birch
- Sky Leite
- TheSunCat
- Thomas
- Tobias Frölich
- Tony Wasserka
- Vincent Riquer
- Virgile Robles
- dddddd-mmmmmm
- gerry_the_hat
- getzze
- heyarne
- jake
- jooola
- jovuit
- nouts
- petitminion
- ppom
- pullopen
- resister
- silksow
- troll

Contributors to our Merge Requests:

- AMoonRabbit
- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Laurin W
- Marcos Peña
- Mathieu Jourdan
- Nicolas Derive
- Philipp Wolfer
- Rodion Borisov
- Thomas
- Tobias Frölich
- getzze
- jooola
- mqus
- petitminion
- poeppe

## 1.2.10 (2023-03-17)

Bugfixes:

- Fixes a security vulnerability that allows to download all media files without access control #2101

Contributors to our Issues:

- Georg Krause
- JuniorJPDJ

Special thanks to Conradowatz for reporting the vulnerability

Committers:

- JuniorJPDJ

## 1.2.9 (2022-11-25)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Ensure index.html files get loaded with UTF-8 encoding
- Fixed invitation reuse after the invited user has been deleted (#1952)
- Fixed unplayable skipped upload (#1349)

Committers:

- Georg Krause
- Marcos Peña
- Philipp Wolfer
- Travis Briggs

Contributors to our Issues:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Marcos Peña
- Mathieu Jourdan
- Micha Gläß-Stöcker
- fuomag9
- gammelalf
- myOmikron
- petitminion

Contributors to our Merge Requests:

- Georg Krause
- JuniorJPDJ
- Marcos Peña
- Philipp Wolfer
- fuomag9

## 1.2.8 (2022-09-12)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Features:

- Add Sentry SDK to collect errors at the backend

Bugfixes:

- Fix exponentially growing database when using in-place-imports on a regular base #1676
- Fix navigating to registration request not showing anything (#1836)
- Fix player cover image overlapping queue list
- Fixed metadata handling for Various Artists albums (#1201)
- Fixed search behaviour in radio builder's filters (#733)
- Fixed unpredictable subsonic search3 results (#1782)

Committers:

- Ciarán Ainsworth
- Georg Krause
- Marcos Peña
- Mathias Koehler
- wvffle

Contributors to our Issues:

- AMoonRabbit
- Agate
- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Kelvin Hammond
- Marcos Peña
- Meliurwen
- Micha Gläß-Stöcker
- Miv2nir
- Sam Birch
- Tolriq
- Tony Wasserka
- f1reflyyyylmao
- heyarne
- petitminion
- troll

Contributors to our Merge Requests:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Marcos Peña
- interru

## 1.2.7 (2022-07-14)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Fixed libre.fm plugin not submitting scrobbles (#1817)

Committers:

- Georg Krause
- Marcos Peña

Contributors to our Issues:

- Ciarán Ainsworth
- Marcos Peña

Contributors to our Merge Requests:

- Georg Krause
- Marcos Peña

## 1.2.6 (2022-07-04)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Channel overview was displaying foreign tracks (#1773)
- Fixed login form focusing reset password link instead of next input (#1373)
- Fixed missing album contextual menu (#1791)
- Fixed single listening submission when repeating a song (#1312)
- Fixed subsonic createPlaylist's endpoint doesn't update playlist (#1263)
- Resolve timeouts if nodeinfo and service actor is not known (#1714)

Other:

- Replaced references to #funkwhale-troubleshooting with #funkwhale-support

Committers:

- Georg Krause
- Marcos Peña
- Petitminion
- wvffle

Contributors to our Issues:

- jeweet
- wvffle
- Georg Krause
- Marcos Peña
- AMoonRabbit
- Micha Gläß-Stöcker
- Ciarán Ainsworth
- heyarne
- Agate
- JuniorJPDJ
- MichaelBechHansen
- ooZberg
- Esras .
- PhieF
- Petitminion

Contributors to our Merge Requests:

- wvffle
- Georg Krause
- Marcos Peña
- Petitminion

## 1.2.5 (2022-05-07)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Parameterize the default S3 ACL when uploading objects. (#1319)

Bugfixes:

- Fix stopped player to not show 00:00 when loading a track (#1432)
- Fixes channel page (#1729) (1729)

Committers:

- Georg Krause
- Marcos
- MattDHarding
- Stuart Begley-Miller

Contributors to our Issues:

- Agate
- Beto Dealmeida
- Cam Sweeney
- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Marcos Peña
- Mathieu Jourdan
- MattDHarding
- Micha Gläß-Stöcker
- Stuart Begley-Miller
- Tony Wasserka
- jovuit
- petitminion
- pullopen

Contributors to our Merge Requests:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Marcos Peña
- MattDHarding
- PhieF
- Stuart Begley-Miller
- petitminion

## 1.2.4 (2022-04-23)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Hand cursor now displayed over artist and album cards

Bugfixes:

- Fixes docs' SMTP URI configuration (#1749) (1749)

Documentation:

- The documentation is now available in two versions: Develop and Stable

Contributors to our Issues:

- Beto Dealmeida
- Cam Sweeney
- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Marcos Peña
- Mathieu Jourdan
- Micha Gläß-Stöcker
- petitminion

Contributors to our Merge Requests:

- Georg Krause
- JuniorJPDJ
- Marcos Peña
- petitminion

Committers:

- Georg Krause
- Marcos Peña
- MattDHarding

## 1.2.3 (2022-03-18)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Added support for all cover sources in the embedded player (#1697).
- Change unmaintained PyMemoize library to django-cache-memoize
  to enable Python 3.10 support

Bugfixes:

- Catch ValueError on radio end (#1596)
- Fix bug that prevents users from creating a new oauth application (#1706)
- Fix failed track adding to playlist being silent (#1020)
- Fix recently added radio not working has expected (#1674)
- Fixed an issue where you couldn't load the details page for tracks with no associated album (#1703)
- Fixed library visibility dropdown (#1384)
- In playlist editor can now click outside the trashcan but inside the button to delete entry (#1348)

Contributors to our Issues:

- Agate
- Baudouin Feildel
- Christoph Pomaska
- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Marcos Peña
- Mathieu Jourdan
- MattDHarding
- Micha Gläß-Stöcker
- dnikolov
- jovuit
- petitminion

Contributors to our Merge Requests:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Kasper Seweryn
- Marcos Peña
- MattDHarding
- petitminion

Committers

- Ciaran Ainsworth
- Georg Krause
- JuniorJPDJ
- MattDHarding
- Petitminion
- Reinhard Prechtl

## 1.2.2 (2022-02-04)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Fix an issue where the tracks tab in a library doesn't show any tracks (#1683)
- Fix an issue with the embedded player not showing any content (#1675)
- Fix broken instance description if it contains a line break #1673

Dependency Updates:

- Update dependency vue-template-compiler to 2.6.14
- Update dependency vue to ^2.6.14
- Update dependency vuex-persistedstate to ^2.7.1
- Update dependency vuedraggable to ^2.24.3
- Update dependency vue-lazyload to ^1.3.3
- Update dependency vue-plyr to ^5.1.3
- Update dependency vue-upload-component to ^2.8.22
- Update dependency vue-gettext to ^2.1.12
- Update dependency showdown to ^1.9.1
- Update dependency js-logger to ^1.6.1
- Update dependency register-service-worker to ^1.7.2
- Update dependency howler to ^2.2.3
- Update dependency fomantic-ui-css to ^2.8.8
- Update dependency diff to ^4.0.2
- Update dependency axios-auth-refresh to ^2.2.8

Contributors to our Issues:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Marcos Peña
- Mathieu Jourdan
- Micha Gläß-Stöcker
- Ricardo
- petitminion

Contributors to our Merge Requests:

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Marcos Peña

Committers

- Ciarán Ainsworth
- Georg Krause
- JuniorJPDJ
- Keunes
- Marcos Peña

## 1.2.1 (2022-01-06)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Fix Pipeline for stable release builds (#1652)
- Fix remote content page (#1655)

Contributors to our Issues:

- Ciarán Ainsworth
- Georg Krause
- Jakob Schürz
- Mathieu Jourdan
- Micha Gläß-Stöcker
- petitminion

Contributors to our Merge Requests:

- Georg Krause

Committers:

- Dignified Silence
- Georg Krause
- JuniorJPDJ
- nztvar

## 1.2.0 (2021-12-27)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Due to a bug in our CI Pipeline, you need to download the frontend artifact here: https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/81069/artifacts/download

If you are running the All-in-One-Container since a longer time, you probably need to manually migrate your database information. If that's the case, you will get a message like this:

`DETAIL: The data directory was initialized by PostgreSQL version 11, which is not compatible with this version 13.5.`

Make sure the Funkwhale version is set to `1.1.4` in `docker-compose.yml`. Now you can run this command to dump the database into a file:

`docker-compose exec -T funkwhale pg_dump -c -U funkwhale > "db.dump"`

Now you can update the Funkwhale version in `docker-compose.yml` to `1.2.0`. Additionally you should save your `data` directory, eg by running `mv data data.bak && mkdir data`. Stop Funkwhale and start it again with the new version, by using `docker-compose down && docker-compose up -d`. This will initialize a fresh DB and applies all migrations. Now you can restore your database with the following command: `cat db.dump | docker-compose exec -T funkwhale psql -U funkwhale`. That's it, enjoy!

Features:

- Implemented awesome recently added radio (part of #1390)
- Rework the instance about page (#1376)
- Made changes to the track table to make it more visibly pleasing

Enhancements:

- Add linting for Frontend code (#1602)
- Add xmlns:content to feed schemas fixes #1535
- Add a Maloja plugin to submit listenings
- Add artist cover art in subsonic API response (#1528)
- Allow listen activities privacy level to be set public
- Allow running multi-container setup on non-root user inside docker (!1375) (fixes #1334)
- Change volume dynamic range from 60dB to 40dB (fixes #1544)
- Change Start Radio to Play Radio (#1400)
- Display toast when subsonic password is copied (#1496)
- Expose more metadata in Subsonic's getAlbumList endpoint (#623)
- ListenBrainz: Submit media player and submission client information
- Make "play in list" the default when interacting with individual tracks (#1274)
- Prevent an uncontrolled exception when uploading a file without tags, and prints user friendly message (1275)
- Remove deprecated JWT Authentication (#1108) (1108)
- Remove Raven SDK to report errors to Sentry (#1425) (1425)
- Replace psycopg2-binary with psycopg2 (#1513)

Bugfixes:

- Add worker-src to nginx header to prevent issues (#1489)
- Enable stepless adjustment of the volume slider (!1294)
- Fix an error in a Subsonic methods that return lists of numbers/strings like getUser
- Fix showing too long radio descriptions (#1556)
- Fix X-Frame-Options HTTP header for embed and force it to SAMEORIGIN value for other pages (fix #1022)
- Fix before last track starts playing when last track removed (#1485)
- Fix delete account button is not disabled when missing password (#1591)
- Fix omputed properties already defined in components data (#1649)
- Fix the all in one docker image building process, related to #1503
- Fix crash in album moderation interface when missing cover (#1474)
- Fix subsonic scrobble not triggering plugin hook (#1416)
- Improve formatting of RSS episode descriptions (#1405)
- Only suggest typed tag once if it already exists
- Partially fixed playing two tracks at same time (#1213)
- Revert changes that break mobile browser playback (#1509)
- Sanitize remote tracks' saving locations with slashes on their names (#1435)
- Show embed option for channel tracks (#1278)
- Store volume in logarithmic scale and convert when setting it to audio (fixes #1543)
- Use global Howler volume instead of setting it separately for each track (fixes #1542)

Documentation:

- Add email configuration to the documentation (#1481)
- Add server uninstallation documentation (\!1314)
- Document location of cli env file on macOS (\!1354)
- Fix broken backup documentation (#1345)
- Refactore installation documentation and other small documentation adjustments (\!1314)
- Add User documentation for built-in plugins

Other:

- Create stable branch, master is now deprecated and will be removed in 1.3 (#1476)

Committers:

- Alexandra Parker
- Alyssa Ross
- appzer0
- Arthur Brugière
- Asier Iturralde Sarasola
- bittin
- Blopware
- Brian McMillen
- Christoph Pomaska
- Ciaran Ainsworth
- Ciarán Ainsworth
- Classified
- Connor Hay
- Damian Szetela
- David Marzal
- Deleted User
- Dignified Silence
- Dominik Danelski
- egon0
- Erik Präntare
- Georg Abenthung
- Georgios B
- Georgios Brellas
- Georg Krause
- ghose
- greengekota
- heyarne
- ian Vatega
- Janek
- jovuit
- JuniorJPDJ
- Konstantinos G
- manuelviens
- Manuel Viens
- Marcos
- Marcos Peña
- Martin Giger
- Matthew J
- Micha Gläß-Stöcker
- petitminion
- Petitminion
- Philipp Wolfer
- Porrumentzio
- Quentin PAGÈS
- Raphael Lullis
- Riccardo Sacchetto
- Romain Failliot
- Rubén Cabrera
- Ryan Harg
- Sergio Varela
- SpcCw
- Stefano Pigozzi
- Thomas
- Tony Simoes
- Tony Wasserka
- vachan-maker
- Virgile Robles

Contributors to our Issues:

- AMoonRabbit
- Agate
- Antoine POPINEAU
- Arthur Brugière
- Ciarán Ainsworth
- Connor Hay
- Creak
- David Marzal
- Georg Krause
- Gerhard Beck
- Greg Poole
- JuniorJPDJ
- Kuba Orlik
- Lunar Control
- Marcos Peña
- Mateusz Korzeniewski
- Mathieu Jourdan
- Micha Gläß-Stöcker
- Philipp Wolfer
- Porrumentzio
- Thomas
- Tony Wasserka
- Ville Ranki
- arkhi
- heyarne
- interfect
- jovuit
- mal
- petitminion
- vachan-maker

Contributors to our Merge Requests:

- Agate
- Arthur Brugière
- Ciarán Ainsworth
- Connor Hay
- David Marzal
- Distopico
- Fanyx
- Georg Abenthung
- Georg Krause
- Janek
- JuniorJPDJ
- Kasper Seweryn
- Marcos Peña
- Mathieu Jourdan
- Matthew J.
- Micha Gläß-Stöcker
- Philipp Wolfer
- Thomas
- Tony Wasserka
- heyarne
- jovuit
- petitminion
- thanksd

## 1.1.4 (2021-08-02)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

- Pinned version of asgiref to avoid trouble with latest release. For further information, see #1516

## 1.1.3 (2021-08-02)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Test better tagging of Docker Images (#1505)

Bugfixes:

- Fix the scrobbler plugin submitting literal "None" as MusicBrainz ID (#1498)
- Add worker-src to nginx header to prevent issues (#1489)
- Only suggest typed tag once if it already exists
- Implement access control on the moderation views (#1494)
- Prevent open redirect on login (#1492)

## 1.1.2 (2021-05-19)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Added modal to prompt users to log in when subscribing to channels (#1296)

Bugfixes:

- Added missing is_playable serializer for the tracks endpoint.
- Fixed minor graphical bug where loaders would appear white in dark theme (#1442)
- Fixed systemd unit for funkwhale-worker (#1160)
- Several minor fixes for the Frontend

## 1.1.1 (2021-04-13)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Improve UI consistency in artist tracks (#1286)
- Adds year to album's card and album's base UI

Bugfixes:

- Fix playback issues when pausing close the the end of a track (#1324)
- Fix tracks playing in the background without the ability to control them (#1213) (#1387)
- Fixed track playback indicator to reset on queue end (#1380)
- Frontend build tooling is less dependent on `npm` or `yarn` being used (!1285)
- Fixed a small discrepancy to the subsonic api 1374

## 1.1 (2021-03-10)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Add number of tracks and discs of an album to API (#1238)
- Add spacing after "Play all" button in playlist view (!1271)
- Added a ListenBrainz plugin to submit listenings
- Added ability to choose fediverse addresses from channel subscription page/podcast screen (#1294)
- Added new search functions to allow users to more easily search for podcasts in the UI.
- Added padding to volume slider to ease mouse control (#1241)
- Logarithmic scale for volume slider (#1222)
- More user-friendly subsonic tokens (#1269)
- Remove manual entry of Import Reference on front-end import (#1284)
- Support AIFF file format (#1243)

Bugfixes:

- "Add check for empty/null covers (#1281)"
- Added an album filter to fix problem where channel entries would show up in the wrong series (#1282)
- Avoid broken Faker version (#1323)
- Changed audio format detection to happen via sniffing and not file extensions (#1274)
- Changed default behaviour of channel entries to use channel artwork if no entry artwork available (#1289)
- Fix delete library modal closing immediately (#1272)
- Fix public shared remote library radio button being disabled (#1292)
- Fixed an issue that prevented disabling plugins
- Fixed an issue where channel albums don't show up in the album search (#1300)
- Fixed an issue where modals would prevent users being able to interact with channels (#1295)
- Update MediaSession metadata for initially loaded track (#1252)
- Update playback position slider also when track is paused (#1266)
- Fixed follows from Pleroma with custom Emoji as Tag by ignoring not supported tag types #1342
- Update pleroma JSON-LD Schema (#1341)
- Pin twisted version to 20.3.0

Contributors to this release (development, documentation, reviews):

- Adam Novak
- Agate
- alemairebe
- Alicia Blasco Leon
- anonymous
- Amaranthe
- appzer0
- Arne
- Asier Iturralde Sarasola
- Christian Paul
- Ciarán Ainsworth
- Daniel
- David
- Dominik Danelski
- Eorn le goéland
- Eleos
- Erik Duxstad
- Esteban
- Fred Uggla
- Freyja Wildes
- Georg Krause
- ghose
- hellekin
- heyarne
- interfect
- Jess Jing
- Johannes H.
- jovuit
- marzzzello
- Meliurwen
- Mehdi
- Nitai Bezerra da Silva
- Philipp Wolfer
- Pierre Couy
- Porrumentzio
- Reg
- Robert Kaye
- Rubén Cabrera
- Silver Fox
- Snack Capt
- SpcCw
- Strom Lin
- vicdorke
- x

## 1.1-rc2 (2021-03-01)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Bugfixes:

- Fixed follows from Pleroma with custom Emoji as Tag by ignoring not supported tag types #1342
- Update pleroma JSON-LD Schema (#1341)
- Revert fork replacement of http-signature since official package breaks federation
- Pin twisted version to 20.3.0

## 1.1-rc1 (2021-02-24)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Add number of tracks and discs of an album to API (#1238)
- Add spacing after "Play all" button in playlist view (!1271)
- Added a ListenBrainz plugin to submit listenings
- Added ability to choose fediverse addresses from channel subscription page/podcast screen (#1294)
- Added new search functions to allow users to more easily search for podcasts in the UI.
- Added padding to volume slider to ease mouse control (#1241)
- Logarithmic scale for volume slider (#1222)
- More user-friendly subsonic tokens (#1269)
- Remove manual entry of Import Reference on front-end import (#1284)
- Replaced forked http-signature dependency with official package (#876)
- Support AIFF file format (#1243)

Bugfixes:

- "Add check for empty/null covers (#1281)"
- Added an album filter to fix problem where channel entries would show up in the wrong series (#1282)
- Avoid broken Faker version (#1323)
- Changed audio format detection to happen via sniffing and not file extensions (#1274)
- Changed default behaviour of channel entries to use channel artwork if no entry artwork available (#1289)
- Fix delete library modal closing immediately (#1272)
- Fix public shared remote library radio button being disabled (#1292)
- Fixed an issue that prevented disabling plugins
- Fixed an issue where channel albums don't show up in the album search (#1300)
- Fixed an issue where modals would prevent users being able to interact with channels (#1295)
- Update MediaSession metadata for initially loaded track (#1252)
- Update playback position slider also when track is paused (#1266)

Contributors to this release (development, documentation, reviews):

- Reg
- hellekin
- Esteban
- Freyja Wildes
- Amaranthe
- Eleos
- Johannes H.
- Mehdi
- Adam Novak
- Agate
- Christian Paul
- Ciarán Ainsworth
- Erik Duxstad
- Fred Uggla
- Georg Krause
- heyarne
- interfect
- jovuit
- Nitai Bezerra da Silva
- Philipp Wolfer
- Pierre Couy
- Robert Kaye
- Strom Lin

## 1.0.1 (2020-10-31)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

Enhancements:

- Added controls to play volume of an album (#1226)
- Allow genre tags to be updated when rescanning files in-place (#1246)

Bugfixes:

- Fixed broken install because of upgraded dependencies
- Fixed duplication of discs for multi-disc albums in album views (#1228)
- Make the generated RSS feed more conformant with w3c specification (#1250)

Contributors to this release (development, documentation, reviews):

- Agate
- Cédric Schieli
- Ciarán Ainsworth
- Kuba Orlik

## 1.0 (2020-09-09)

Upgrade instructions are available at
https://docs.funkwhale.audio/administrator/upgrade/index.html

### Dropped python 3.5 support [manual action required, non-docker only]

With Funkwhale 1.0, we're dropping support for Python 3.5. Before upgrading,
ensure `python3 --version` returns `3.6` or higher.

If it returns `3.6` or higher, you have nothing to do.

If it returns `3.5`, you will need to upgrade your Python version/Host, then recreate your virtual environment:

```sh
rm -rf /srv/funkwhale/virtualenv
python3 -m venv /srv/funkwhale/virtualenv
```

### Increased quality of JPEG thumbnails [manual action required]

Default quality for JPEG thumbnails was increased from 70 to 95, as 70 was producing visible artifacts in resized images.

Because of this change, existing thumbnails will not load, and you will need to:

1. delete the `__sized__` directory in your `MEDIA_ROOT` directory
2. run `python manage.py fw media generate-thumbnails` to regenerate thumbnails with the enhanced quality

If you don't want to regenerate thumbnails, you can keep the old ones by adding `THUMBNAIL_JPEG_RESIZE_QUALITY=70` to your .env file.

### Small API breaking change in `/api/v1/libraries`

To allow easier crawling of public libraries on a pod,we had to make a slight breaking change
to the behaviour of `GET /api/v1/libraries`.

Before, it returned only libraries owned by the current user.

Now, it returns all the accessible libraries (including ones from other users and pods).

If you are consuming the API via a third-party client and need to retrieve your libraries,
use the `scope` parameter, like this: `GET /api/v1/libraries?scope=me`

### API breaking change in `/api/v1/albums`

To increase performance, querying `/api/v1/albums` doesn't return album tracks anymore. This caused
some performance issues, especially as some albums and series have dozens or even hundreds of tracks.

If you want to retrieve tracks for an album, you can query `/api/v1/tracks/?album=<albumid>`.

### JWT deprecation

API Authentication using JWT is deprecated and will be removed in Funkwhale 1.0. Please use OAuth or application tokens
and refer to our API documentation at https://docs.funkwhale.audio/swagger/ for guidance.

### Full list of changes

Features:

- Allow users to hide compilation artists on the artist search page (#1053)
- Can now launch server import from the UI (#1105)
- Dedicated, advanced search page (#370)
- Persist theme and language settings across sessions (#996)

Enhancements:

- Add support for unauthenticated users hitting the logout page
- Added support for Licence Art Libre (#1088)
- Broadcast/handle rejected follows (#858)
- Confirm email without requiring the user to validate the form manually (#407)
- Display channel and track downloads count (#1178)
- Do not include tracks in album API representation (#1102)
- Dropped python 3.5 support. Python 3.6 is the minimum required version (#1099)
- Improved keyboard accessibility (#1125)
- Improved naming of pages for accessibility (#1127)
- Improved shuffle behaviour (#1190)
- Increased quality of JPEG thumbnails
- Lock focus in modals to improve accessibility (#1128)
- More consistent search UX on /albums, /artists, /radios and /playlists (#1131)
- Play button now replace current queue instead of appending to it (#1083)
- Set proper lang attribute on HTML document (#1130)
- Use semantic headers for accessibility (#1121)
- Users can now update their email address (#292)
- [plugin, scrobbler] Use last.fm API v2 for scrobbling if API key and secret are provided
- Added a new, large thumbnail size for cover images (#1205
- Enforce authentication when viewing remote channels, profiles and libraries (#1210)

Bugfixes:

- Fix broken media support detection (#1180)
- Fix layout issue with playbar on landscape tablets (#1144)
- Fix random radio so that podcast content is not picked up (#1140)
- Fixed an issue with search pages where results would not appear after navigating to another page
- Fixed crash with negative track position in file tags (#1193)
- Handle access errors scanning directories when importing files
- Make channel card updated times more humanly readable, add internationalization (#1089)
- Ensure search page reloads if another search is submitted in the sidebar (#1197)
- Fixed "scope=subscribed" on albums, artists, uploads and libraries API (#1217)
- Fixed broken federation with pods using allow-listing (#1999)
- Fixed broken search when using (, " or & chars (#1196)
- Fixed domains table hidden controls when no domains are found (#1198)

Documentation:

- Simplify Docker mono-container installation and upgrade documentation

Contributors to this release (translation, development, documentation, reviews, design, testing, third-party projects):

- Agate
- Andy Craze
- anonymous
- appzer0
- Arne
- Ciarán Ainsworth
- Daniele Lira Mereb
- dulz
- Francesc Galí
- ghose
- Kalle Anka
- mekind
- Meliurwen
- Puri
- Quentin PAGÈS
- Raphaël Ventura
- Slimane Selyan Amiri
- SpcCw
- Stefano Pigozzi
- Sébastien de Melo
- Ventura Pérez García
- vicdorke
- Xosé M
