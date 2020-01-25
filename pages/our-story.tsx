import styled from 'styled-components'
import Link from 'next/link'
import Prismic from 'prismic-javascript'
import { RichText } from 'prismic-reactjs'

import Header from '../components/header'
import Footer from '../components/footer'
import Timeline, { Year } from '../components/timeline'
import ImageBlock from '../components/imageBlock'
import ThreeUp from '../components/threeUp'
import { Content, Bar } from '../components/layout'
import IconStack from '../components/iconStack'

import PrismicClient from '../prismic-client'

interface Year {
  id: string
  data: {
    year: {
      text: string
    }
    main_image: {
      url: string
    }
    content: string
    description: string
  }
}

interface Props {
  years: Array<Year>
}

const OurStory = ({ years }: Props) => (
  <div>
    <Header title="Our Story" />
    <Content>
      <Timeline>
        {years.map(({ id, data }) => (
          <Year key={id} image={data.main_image.url}>
            <RichText render={data.year} />
            <RichText render={data.description} />
          </Year>
        ))}
      </Timeline>
      <ThreeUp>
        <ImageBlock
          image="images/friends.jpg"
          title="What to Expect"
          link="/what-to-expect"
        />
        <ImageBlock
          image="images/snowmobiles.jpg"
          title="Itinerary"
          link="/itinerary"
        />
        <ImageBlock
          image="images/bikes.jpg"
          title="Camp Life"
          link="/camp-life"
        />
      </ThreeUp>
    </Content>
    <Footer />
  </div>
)

OurStory.getInitialProps = async () => {
  const resp = await PrismicClient.query(
    Prismic.Predicates.at('document.type', 'year'),
    {}
  )
  console.log(resp.results[0])
  return {
    years: resp.results.map(result => result),
  }
}

export default OurStory
