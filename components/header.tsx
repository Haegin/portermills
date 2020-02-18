import styled from 'styled-components'
import { transparentize } from 'polished'
import Link from 'next/link'

const Container = styled.div`
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  align-items: center;
  height: 650px;
  background-position: center bottom;
  background-image: linear-gradient(
      to bottom,
      ${p => p.theme.colors.primaryText},
      ${p => transparentize(0.2, p.theme.colors.primaryText)} 20%,
      rgba(0, 0, 0, 0) 60%,
      rgba(0, 0, 0, 0)
    ),
    url(/images/on-the-lake.jpg);
  background-position: center, center;
  background-size: cover, cover;

  h1 {
    color: ${p => p.theme.colors.beige};
    text-shadow: 0 0 1rem ${p => p.theme.colors.primaryText};
  }
`

const SecondaryNav = styled.div`
  display: flex;
  flex-direction: row;
  justify-content: flex-end;
  margin-top: 3rem;
  width: 1400px;
  margin: 0 auto;
  margin-top: 2rem;

  & a {
    color: ${p => p.theme.colors.beige};
    text-decoration: none;
    margin-left: 2rem;
  }

  & a:hover {
    font-weight: 900;
    text-shadow: 0 0 1rem ${p => p.theme.colors.beige};
  }
`

const PrimaryNav = styled.div`
  display: flex;
  flex-direction: row;
  justify-content: space-around;
  align-items: center;
  width: 1200px;
  margin: 0 auto;
  margin-top: 2rem;

  & a {
    text-transform: uppercase;
    text-decoration: none;
    font-size: 1.5rem;
    font-weight: 600;
    color: ${p => p.theme.colors.beige};
  }

  & a:hover {
    font-weight: 900;
    text-shadow: 0 0 1rem ${p => p.theme.colors.beige};
  }

  & img {
    width: 5.5rem;
    height: 5.5rem;
  }
`

interface Props {
  title?: string
}

const Header = ({ title }: Props) => (
  <Container>
    <SecondaryNav>
      <Link href="/registry">
        <a>Registry</a>
      </Link>
      <Link href="/rsvp">
        <a>RSVP</a>
      </Link>
      <Link href="/photos">
        <a>Photos</a>
      </Link>
    </SecondaryNav>
    <PrimaryNav>
      <Link href="/our-story">
        <a>Our Story</a>
      </Link>
      <Link href="/what-to-expect">
        <a>What to Expect</a>
      </Link>
      <Link href="/itinerary">
        <a>Itinerary</a>
      </Link>
      <img src="/images/portermills-camp.jpg" alt="Portermills Camp" />
      <Link href="/camp-life">
        <a>Camp Life</a>
      </Link>
      <Link href="/travel">
        <a>Travel</a>
      </Link>
      <Link href="/staying-on">
        <a>Staying On</a>
      </Link>
    </PrimaryNav>
    {title && <h1>{title}</h1>}
  </Container>
)

export default Header
