import styled from 'styled-components'
import Link from 'next/link'

const TabContainer = styled.ul`
  list-style-type: none;
  display: flex;
  flex-direction: row;
`

const Tab = styled.li<{ selected?: boolean }>`
  padding: 1rem;
  ${props => props.selected && `text-decoration: underline;`}
`

const ItineraryNav = ({ current }) => {
  return (
    <TabContainer>
      <Tab selected={current == 'friday'}>
        <Link
          replace
          scroll={false}
          href="/itinerary/[day]"
          as="/itinerary/friday">
          Friday
        </Link>
      </Tab>
      <Tab selected={current == 'saturday'}>
        <Link
          replace
          scroll={false}
          href="/itinerary/[day]"
          as="/itinerary/saturday">
          Saturday
        </Link>
      </Tab>
      <Tab selected={current == 'sunday'}>
        <Link
          replace
          scroll={false}
          href="/itinerary/[day]"
          as="/itinerary/sunday">
          Sunday
        </Link>
      </Tab>
      <Tab selected={current == 'monday'}>
        <Link
          replace
          scroll={false}
          href="/itinerary/[day]"
          as="/itinerary/monday">
          Monday
        </Link>
      </Tab>
    </TabContainer>
  )
}

export default ItineraryNav
