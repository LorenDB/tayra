<template>
  <div class="main pusher page-library">
    <router-view :key="$router.currentRoute.value.fullPath" />
  </div>
</template>
