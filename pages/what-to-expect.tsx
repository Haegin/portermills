import styled from 'styled-components'
import { transparentize } from 'polished'
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
  margin-bottom: calc(6.25rem + 8rem);

  & h5 {
    width: 50%;
    align-self: flex-end;
    text-shadow: 0 0 0.5rem ${p => p.theme.colors.beige};
    padding: 2rem 2rem 0rem 2rem;
    margin-bottom: 0;
    background-image: linear-gradient(
      to right,
      ${p => p.theme.colors.beige},
      ${p => transparentize(0.2, p.theme.colors.beige)} 20%,
      rgba(0, 0, 0, 0) 60%,
      rgba(0, 0, 0, 0)
    );
  }

  & p {
    width: 50%;
    align-self: flex-end;
    padding: 2rem;
    margin-top: 0;
    background-image: linear-gradient(
      to right,
      ${p => p.theme.colors.beige},
      ${p => transparentize(0.2, p.theme.colors.beige)} 20%,
      rgba(0, 0, 0, 0) 60%,
      rgba(0, 0, 0, 0)
    );
  }

  & img {
    width: 60%;
    height: 100%;
    object-fit: cover;
    position: absolute;
    z-index: -5;
    clip-path: content-box;
  }
`

const TwoColumns = styled.div`
  columns: 350px auto;
  column-gap: 2rem;
  margin-bottom: 8rem;

  img {
    margin: 1.5rem 0;
  }
`

const WhatToExpect = () => (
  <div>
    <Header />
    <Content>
      <Intro>
        <img src="/images/going-to-waupoos.jpg" />
        <h5>
          Porter-Mills Camp is not your typical weekend getaway, and nor will it
          be your typical wedding!
        </h5>
        <p>
          We wanted something a little different for our special day. Something
          that was reflective of us as a couple, our interests, our values, and
          our new hometown. Here's what you can expect from Porter-Mills Camp.
        </p>
      </Intro>
      <Bar>
        <section>
          <h3>Our Goals</h3>
          <div>
            <IconStack title="Quality Time" icon="ICON">
              <p>
                We wanted something a little different for our special day.
                Something that was reflective of us as a couple, our interests,
                our values, and our new hometown. Here's what you can expect
                from Porter-Mills Camp.
              </p>
            </IconStack>
            <IconStack title="CALL IT &ldquo;QUAINT&rdquo;" icon="ICON">
              <p>
                We've kept our guest list small to allow all of our loved ones
                (that's you!) to get acquainted with one another. A smaller
                guest list also meant that we could find a venue with
                accommodation for us and all our our guests.
              </p>
            </IconStack>
            <IconStack title="IT'S FALL Y'ALL" icon="ICON">
              <p>
                We always knew our day our also be a celebration our favourite
                season: Autumn in Canada. Think changing leaves, great lakes
                sparking in the sunshine, sipping craft beer in open fields,
                crisp foggy mornings wrapped in blankets and cool nights spent
                by the campfire sipping whisky - have we painted a picture?
              </p>
            </IconStack>
            <IconStack title="KEEP IT LOCAL" icon="ICON">
              <p>
                Having recently made our home in Prince Edward County, it was
                important to us to keep our celebration as local as possible.
                We're excited for you to experience the County's bounty, from
                the produce you'll eat to the beer (and wine! and gin! and
                whisky!) you'll drink, it'll all be from right here.
              </p>
            </IconStack>
          </div>
          <Link href="/the-weekend">
            <button>RSVP</button>
          </Link>
        </section>
      </Bar>
      <h4>ABOUT THE VENUE</h4>
      <TwoColumns>
        <p>
          The Camp at Waupoos Island is a beautiful 14 acre property on - you
          guessed it - Waupoos Island, located just off the south east coast of
          Prince Edward County on Lake Ontario. The island is a quick 5-minute
          boat ride from Waupoos Marina, which itself is just a 15 minute drive
          from Picton.
        </p>

        <p>
          The property consists of 7 3-bedroom cabins and a refurbishsed 10 -
          bedroom dormitory as well as a multi-use space referred to as "the
          church." All of the cabins are equipped with a full bathroom and
          kitchen, and the dormitory has multiple shared bathrooms and a
          communal kitchen on its ground floor.
        </p>

        <p>
          There's plenty to do on the island, with access to canoes, SUPs and
          kayaks for those drawn to water, and for those who prefer dry land we
          recommend a walk around the island's only "road" to meet the
          neighbours (mostly sheep).
        </p>

        <img src="images/on-the-lake.jpg" />

        <p>
          You can learn more about how accommodation will work on the Camp Life
          page, and we encourage you to take a gander at the venue's website at
          the link below.
        </p>
      </TwoColumns>
      <ImageBlock
        title="Canadian Thanksgiving"
        button="Read On"
        link="/canadian-thanksgiving"
        image="/images/friends.jpg"
        imagePos="right">
        <p>
          No matter where you're travelling from, we've got you covered! Get to
          the County - and to Waupoos Island - safe and sound with these tips.
        </p>
      </ImageBlock>
      <ThreeUp>
        <ImageBlock
          title="What To Expect"
          button="Learn More"
          link="/what-to-expect"
          image="/images/beaus.jpg"
          imagePos="top"></ImageBlock>
        <ImageBlock
          title="Itinerary"
          button="Learn More"
          link="/itinerary"
          image="/images/snowmobiles.jpg"
          imagePos="top"></ImageBlock>
        <ImageBlock
          title="Camp Life"
          button="Learn More"
          link="/camp-life"
          image="/images/fireworks.jpg"
          imagePos="top"></ImageBlock>
      </ThreeUp>
    </Content>
    <Footer />
  </div>
)

export default WhatToExpect
