import styled from 'styled-components'
import Link from 'next/link'

import Header from '../components/header'
import Footer from '../components/footer'
import ImageBlock from '../components/imageBlock'
import ThreeUp from '../components/threeUp'
import { Content, Bar } from '../components/layout'
import IconStack from '../components/iconStack'

const Intro = styled.div`
  display: flex;
  flex-direction: column;
  width: 100%;
  position: relative;
  margin-top: 5rem;
  margin-bottom: calc(6.25rem + 8rem);

  & h2 {
    width: 40%;
  }

  & h5 {
    width: 50%;
    align-self: flex-end;
    text-shadow: 0 0 0.5rem ${p => p.theme.colors.beige};
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
        <h2>Welcome to Porter-Mills Camp</h2>
        <img src="/images/going-to-waupoos.jpg" />
        <h5>
          Get ready for a weekend of family, friends, fun and (hopefully) some
          glorious October sun in beautiful Prince Edward County, Ontario.
        </h5>
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
          <h3>The Weekend</h3>
          <div>
            <IconStack title="The Day Before" icon="09-10-2020">
              <p>
                Guests are welcome to arrive Friday afternoon or in the evening.
              </p>
            </IconStack>
            <IconStack title="The Big Day" icon="10-10-2020">
              <p>
                Guests are welcome to arrive Friday afternoon or in the evening.
              </p>
            </IconStack>
            <IconStack title="Thanksgiving" icon="11-10-2020">
              <p>
                Guests are welcome to arrive Friday afternoon or in the evening.
              </p>
            </IconStack>
            <IconStack title="The Day After" icon="12-10-2020">
              <p>
                Guests are welcome to arrive Friday afternoon or in the evening.
              </p>
            </IconStack>
          </div>
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
    <Footer />
  </div>
)

export default Index
