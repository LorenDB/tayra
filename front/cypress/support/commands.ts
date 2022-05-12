// Currently we cannot login purely programmatically, so we need to use the
// graphical login until the vue3 branch is merged
Cypress.Commands.add('login', () => {
  cy.fixture('testuser.json').then((user) => {
    var username = user["username"]
    var password = user["password"]
    cy.visit('/login')
    cy.wait(1000)
    cy.getCookie('csrftoken').then(($cookie) => {
      const csrfToken = $cookie?.value

      cy.request({
        method: 'POST',
        url: '/api/v1/users/login',
        form: true,
        headers: {
          'X-CSRFTOKEN': csrfToken,
          Referer: Cypress.config().baseUrl + '/login',
        },
        body: {
          username,
          password
        },
      })
    })
  })
})
