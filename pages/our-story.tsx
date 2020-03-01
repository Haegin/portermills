import styled from 'styled-components'
import Link from 'next/link'
import Head from 'next/head'
import Prismic from 'prismic-javascript'
import { RichText, RichTextContent } from 'prismic-reactjs'

import Header from '../components/header'
import Footer from '../components/footer'
import Timeline, { Year } from '../components/timeline'
import ImageBlock from '../components/imageBlock'
import ThreeUp from '../components/threeUp'
import { Content, Bar } from '../components/layout'
import IconStack from '../components/iconStack'

import PrismicClient from '../prismic-client'

interface Image {
  dimensions: { width: number; height: number }
  alt: string | null
  url: string
}

interface MainImage extends Image {
  thumb: Image
}

interface GalleryEntry {
  gallery_image: Image
}

interface Year {
  id: string
  data: {
    year: {
      text: string
    }
    description: RichTextContent
    main_image: MainImage
    gallery: Array<GalleryEntry>
  }
}

interface Props {
  years: Array<Year>
}

const OurStory = ({ years }: Props) => (
  <div>
    <Head>
      <title>Porter-Mills: Story</title>
      <meta name="viewport" content="initial-scale=1.0, width=device-width" />
    </Head>
    <Header title="Our Story" />
    <Content>
      <Timeline>
        {years.map(({ id, data }) => (
          <Year
            key={id}
            image={
              data.main_image.thumb
                ? data.main_image.thumb.url
                : data.main_image.url
            }
            gallery={data.gallery}>
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
  return {
    years: resp.results.map(result => result),
  }
}

export default OurStory
