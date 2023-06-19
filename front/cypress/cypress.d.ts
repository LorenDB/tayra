declare module 'cypress' {
  global {
    namespace Cypress {
      interface Chainable {
        login(): Chainable<JQuery<HTMLElement>>
      }
    }
  }
}
