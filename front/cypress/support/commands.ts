Cypress.Commands.add('login', () => {
  cy.fixture('testuser.json').then(({ username, password }) => {
    // We need to request a page that sets the csrf cookie
    cy.request('/api/v1/instance/nodeinfo/2.0/')

    cy.getCookie('csrftoken').then(($cookie) => {
      cy.request({
        method: 'POST',
        url: '/api/v1/users/login',
        form: true,
        headers: {
          'X-CSRFTOKEN': $cookie?.value,
          Referer: Cypress.config().baseUrl + '/login'
        },
        body: {
          username,
          password
        }
      })
    })
  })
})
