<script>
export default {
  computed: {
    themes () {
      return [
        {
          icon: 'palette icon',
          name: this.$pgettext('*/Settings/Dropdown.Label/Theme name', 'Browser default'),
          key: 'system'
        },
        {
          icon: 'sun icon',
          name: this.$pgettext('*/Settings/Dropdown.Label/Theme name', 'Light'),
          key: 'light'
        },
        {
          icon: 'moon icon',
          name: this.$pgettext('*/Settings/Dropdown.Label/Theme name', 'Dark'),
          key: 'dark'
        }
      ]
    }
  }
}
</script>
