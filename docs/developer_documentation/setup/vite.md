# Develop using Vite

If you want to make changes to the frontend, you can use Vite to run a development server. This allows you to run a Funkwhale web app and see changes in real time

1. Clone the repository:

   ::::{tab-set}

   :::{tab-item} SSH

   ```sh
   git clone git@dev.funkwhale.audio/funkwhale/funkwhale.git
   cd funkwhale/front
   ```

   :::

   :::{tab-item} HTTPS

   ```sh
   git clone https://dev.funkwhale.audio/funkwhale/funkwhale.git
   cd funkwhale/front
   ```

   :::

   ::::

2. Install [Node.js](https://nodejs.org/en/download/package-manager/) and [Yarn](https://classic.yarnpkg.com/lang/en/docs/install/)
3. Install all dependencies:

   ```sh
   yarn install
   ```

4. Compile the translations:

   ```sh
   yarn i18n-compile
   ```

5. Launch the development server:

   ```sh
   yarn dev
   ```

You can access the Funkwhale web app at `http://localhost:8000/front`. Connect this app to your pod by selecting {guilabel}`Switch instance` in the sidebar.
