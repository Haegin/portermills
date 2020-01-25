import 'sscaffold-css'
// import '~/styles/reset.css'
import '~/styles/global.css'

import { ThemeProvider } from 'styled-components'

import theme from '../theme.ts'

// This default export is required in a new `pages/_app.js` file.
export default function MyApp({ Component, pageProps }) {
  return (
    <ThemeProvider theme={theme}>
      <Component {...pageProps} />
    </ThemeProvider>
  )
}
