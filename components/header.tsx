import styled from 'styled-components'
import { transparentize } from 'polished'
import Link from 'next/link'

const Container = styled.div`
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  height: 650px;
  background-position: center bottom;
  background-image: linear-gradient(
      to bottom,
      ${p => p.theme.colors.blue},
      rgba(0, 0, 0, 0) 45%,
      rgba(0, 0, 0, 0)
    ),
    url(/images/on-the-lake.jpg);
  background-position: center, center;
  background-size: cover, cover;
`

const SecondaryNav = styled.div`
  display: flex;
  flex-direction: row;
  justify-content: flex-end;
  margin-top: 3rem;
  width: 1400px;
  margin: 0 auto;

  & a {
    color: ${p => p.theme.colors.beige};
    text-decoration: none;
    font-size: 0.875rem;
    margin-left: 2rem;
  }
`

const PrimaryNav = styled.div`
  display: flex;
  flex-direction: row;
  justify-content: space-around;
  align-items: center;
  width: 1200px;
  margin: 0 auto;

  & a {
    text-transform: uppercase;
    text-decoration: none;
    font-size: 1.5;
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

const Header = () => (
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
      <Link href="/our-story">
        <a>Our Story</a>
      </Link>
      <Link href="/what-to-expect">
        <a>What to Expect</a>
      </Link>
      <Link href="/itinerary">
        <a>Itinerary</a>
      </Link>
    </PrimaryNav>
  </Container>
)

export default Header
