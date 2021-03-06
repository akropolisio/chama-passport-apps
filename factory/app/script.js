import '@babel/polyfill'

import Aragon from '@aragon/client'

const app = new Aragon()

const initialState = {
  count: 0,
  identity: null,
}
app.store(async (state, event) => {
  if (state === null) state = initialState

  switch (event.event) {
    case 'Registration':
      return {
        count: await getValue(),
        identity: await getMyIdentity()
      }
    default:
      return state
  }
})

function getValue() {
  // Get current value from the contract by calling the public getter
  return new Promise(resolve => {
    app
      .call('value')
      .first()
      .map(value => parseInt(value, 10))
      .subscribe(resolve)
  })
}

function getMyIdentity() {
  return new Promise(resolve => {
    app
      .call('getMyIdentity')
      .first()
      .map(value => value ? {
        age: value[0],
        firstName: value[1],
        lastName: value[2],
      } : null)
      .subscribe(resolve)
  })
}
