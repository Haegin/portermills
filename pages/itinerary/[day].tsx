import styled from 'styled-components'
import Link from 'next/link'
import Head from 'next/head'
import { useRouter } from 'next/router'
import Prismic from 'prismic-javascript'
import { RichText, RichTextContent } from 'prismic-reactjs'
import dayjs from 'dayjs'

import Header from '../../components/header'
import Footer from '../../components/footer'
import { Content } from '../../components/layout'
import ItineraryNav from '../../components/ItineraryNav'

import PrismicClient from '../../prismic-client'

const DATE_FORMAT = 'YYYY-MM-DD'
const TIME_FORMAT = 'HH:mm'

interface TimelineItem {
  id: string
  data: {
    timeline_item: {
      text: string
    }
    what: string
    when: string
    description: RichTextContent
  }
}

interface Props {
  items: Array<TimelineItem>
}

const Itinerary = ({ items }: Props) => {
  const router = useRouter()
  const { day } = router.query
  const date = getDate(day as string)
  const itemsToday = itemsOnDay(items, date)
  return (
    <div>
      <Head>
        <title>Porter-Mills: Itinerary</title>
        <meta name="viewport" content="initial-scale=1.0, width=device-width" />
      </Head>
      <Header title="Itinerary" />
      <Content>
        <h3>
          So, what will you get up to for a whole weekend on an island in
          October in Prince Edward County?
        </h3>
        <p>
          Lots of fun, that's what! We have a whole weekend of activities
          planned so everyone is happy and entertained. That said, we hope that
          you take this weekend as an opportunity to unwind and relax in a
          beautiful setting.
        </p>
        <ItineraryNav current={day} />
        {itemsToday.map(item => (
          <p>
            {dayjs(item.data.when).format(TIME_FORMAT)} -{' '}
            {RichText.asText(item.data.what)}
          </p>
        ))}
      </Content>
      <Footer />
    </div>
  )
}

const itemsOnDay = (items: Array<TimelineItem>, day: string) => {
  const inDay = (time: string) => dayjs(time).format(DATE_FORMAT) === day
  return items.filter(item => inDay(item.data.when))
}

const getDate = (day = 'friday') =>
  ({
    friday: '2020-10-09',
    saturday: '2020-10-10',
    sunday: '2020-10-11',
    monday: '2020-10-12',
  }[day])

Itinerary.getInitialProps = async () => {
  const resp = await PrismicClient.query(
    Prismic.Predicates.at('document.type', 'itinerary_item'),
    {}
  )
  return {
    items: resp.results.map(result => result),
  }
}

export default Itinerary
