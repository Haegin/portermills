import styled from 'styled-components'
import Link from 'next/link'
import Head from 'next/head'
import { useRouter } from 'next/router'
import Prismic from 'prismic-javascript'
import { RichText, RichTextContent } from 'prismic-reactjs'
import dayjs, { Dayjs } from 'dayjs'

import Header from '../components/header'
import Footer from '../components/footer'
import { Content } from '../components/layout'

import PrismicClient from '../prismic-client'

interface TimelineItem {
  id: string
  data: {
    timeline_item: {
      text: string
    }
    description: RichTextContent
    when: Date
  }
}

interface Props {
  items: Array<TimelineItem>
}

const Itinerary = ({ items }: Props) => {
  const router = useRouter()
  router.push("/itinerary/friday")
}

const itemsOnDay = (items: Array<TimelineItem>, day: Dayjs) => {
  const inDay = (time: Date) =>
    dayjs(time).isAfter(day) && dayjs(time).isBefore(day.add(1, 'day'))
  return items.filter(item => inDay(item.data.when))
}

const getDate = (day = 'friday') =>
  dayjs(
    {
      friday: new Date(2020, 10, 9),
      saturday: new Date(2020, 10, 10),
      sunday: new Date(2020, 10, 11),
      monday: new Date(2020, 10, 12),
    }[day]
  )

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
