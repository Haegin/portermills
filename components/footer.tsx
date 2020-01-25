import styled from 'styled-components'
import Link from 'next/link'

const Container = styled.footer`
  background-color: ${p => p.theme.colors.blue};
  margin-top: 8rem;

  section {
    display: flex;
    width: 960px;
    margin: auto;
    padding: 2rem 0;
    flex-direction: row;
    align-items: flex-start;
    justify-content: space-between;
  }

  img {
    width: 100px;
    height: 100px;
  }

  nav {
    display: flex;
    flex-direction: row;
    ul {
      margin-right: 2rem;
      li {
        list-style-type: none;
        margin: 0;
        margin-top: 1rem;
        padding: 0;
        a {
          color: ${p => p.theme.colors.beige};
        }
      }
    }
  }

  aside {
    color: ${p => p.theme.colors.beige};
    align-self: center;
    font-size: 3rem;
  }
`

const Footer = () => (
  <Container>
    <section>
      <img src="/images/portermills-camp.jpg" alt="Portermills Camp" />
      <nav>
        <ul>
          <li>
            <Link href="/">
              <a>Home</a>
            </Link>
          </li>
          <li>
            <Link href="/our-story">
              <a>Our Story</a>
            </Link>
          </li>
          <li>
            <Link href="/what-to-expect">
              <a>What to Expect</a>
            </Link>
          </li>
          <li>
            <Link href="/itinarary">
              <a>Itinarary</a>
            </Link>
          </li>
          <li>
            <Link href="/camp-life">
              <a>Camp Life</a>
            </Link>
          </li>
        </ul>
        <ul>
          <li>
            <Link href="/travel">
              <a>Travel</a>
            </Link>
          </li>
          <li>
            <Link href="/staying-on">
              <a>Staying On</a>
            </Link>
          </li>
          <li>
            <Link href="/registry">
              <a>Registry</a>
            </Link>
          </li>
          <li>
            <Link href="/rsvp">
              <a>RSVP</a>
            </Link>
          </li>
          <li>
            <Link href="/photos">
              <a>Photos</a>
            </Link>
          </li>
        </ul>
      </nav>
      <aside>#portermillscamp</aside>
    </section>
  </Container>
)

export default Footer
