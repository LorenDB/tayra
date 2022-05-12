describe('The login', () => {
  it('is working with UI', () => {
    cy.fixture('testuser.json').then((user) => {
      cy.visit('/login')
      cy.get('input[name=username]').type(user['username'])
      cy.get('input[name=password]').type(`${user['password']}{enter}`)
    })

    cy.url().should('include', '/library')
    cy.getCookie('sessionid').should('exist')
  })

  it('is working without UI', () => {
    cy.login()
    cy.visit('/library')
    cy.get('.ui.avatar.circular.label').should('exist')
    cy.getCookie('sessionid').should('exist')
  })
})
