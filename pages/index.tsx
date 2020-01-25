import styled from 'styled-components'
import Link from 'next/link'

import Header from '../components/header'
import ImageBlock from '../components/imageBlock'
import ThreeUp from '../components/threeUp'
import { Content, Bar } from '../components/layout'

const Intro = styled.div`
  display: flex;
  flex-direction: column;
  width: 100%;
  position: relative;
  margin-top: 5rem;
  margin-bottom: calc(6.25rem + 8rem);

  & h1 {
    width: 40%;
  }

  & h3 {
    width: 50%;
    align-self: flex-end;
  }

  & p {
    width: 30%;
    align-self: flex-end;
  }

  & img {
    width: 60%;
    height: 100%;
    object-fit: cover;
    position: absolute;
    left: 6.25rem;
    top: 6.25rem;
    z-index: -5;
    clip-path: content-box;
  }
`

const Index = () => (
  <div>
    <Header />
    <Content>
      <Intro>
        <h1>Welcome to Porter-Mills Camp</h1>
        <img src="/images/going-to-waupoos.jpg" />
        <h3>
          Get ready for a weekend of family, friends, fun and (hopefully) some
          glorious October sun in beautiful Prince Edward County, Ontario.
        </h3>
        <p>
          Join us at the Camp at Waupoos Island on Thanksgiving Weekend 2020 for
          good food, great beer and - oh yeah! - a wedding!
        </p>
      </Intro>
      <ImageBlock
        title="Our Story"
        button="Read More"
        link="/our-story"
        image="/images/friends.jpg"
        imagePos="right">
        <p>
          If you're reading this you likely already know us, but visit this
          section to learn more about the Porter and the Mills of Porter-Mills
          Camp. There's a photo gallery too!
        </p>
      </ImageBlock>
      <ThreeUp>
        <ImageBlock
          title="What To Expect"
          button="Learn More"
          link="/what-to-expect"
          image="/images/beaus.jpg"
          imagePos="top">
          <p>
            If you're reading this you likely already know us, but visit this
            section to learn more about the Porter and the Mills of Porter-Mills
            Camp. There's a photo gallery too!
          </p>
        </ImageBlock>
        <ImageBlock
          title="Itinerary"
          button="Learn More"
          link="/itinerary"
          image="/images/snowmobiles.jpg"
          imagePos="top">
          <p>
            If you're reading this you likely already know us, but visit this
            section to learn more about the Porter and the Mills of Porter-Mills
            Camp. There's a photo gallery too!
          </p>
        </ImageBlock>
        <ImageBlock
          title="Camp Life"
          button="Learn More"
          link="/camp-life"
          image="/images/fireworks.jpg"
          imagePos="top">
          <p>
            If you're reading this you likely already know us, but visit this
            section to learn more about the Porter and the Mills of Porter-Mills
            Camp. There's a photo gallery too!
          </p>
        </ImageBlock>
      </ThreeUp>
      <ImageBlock
        title="Travel"
        button="Read More"
        link="/travel"
        image="/images/bikes.jpg"
        imagePos="left">
        <p>
          If you're reading this you likely already know us, but visit this
          section to learn more about the Porter and the Mills of Porter-Mills
          Camp. There's a photo gallery too!
        </p>
      </ImageBlock>
      <Bar>
        <section>
          <h2>The Weekend</h2>
          <Link href="/the-weekend">
            <button>RSVP</button>
          </Link>
        </section>
      </Bar>
      <ImageBlock
        title="Staying On"
        button="Learn More"
        link="/staying-on"
        image="/images/kevin-caitlin.jpg"
        imagePos="right">
        <p>
          If you're reading this you likely already know us, but visit this
          section to learn more about the Porter and the Mills of Porter-Mills
          Camp. There's a photo gallery too!
        </p>
      </ImageBlock>
    </Content>
  </div>
)

export default Index
