import React, { ReactNode } from 'react'
import Link from 'next/link'
import styled from 'styled-components'

const Container = styled.div<Pick<Props, 'imagePos'>>`
  display: flex;
  flex-direction: ${p =>
    p.imagePos === 'top'
      ? 'column'
      : p.imagePos === 'left'
      ? 'row'
      : 'row-reverse'};
  ${p =>
    p.imagePos === 'top' &&
    `
    width: 300px;
  `}

  div {
    display: flex;
    flex-direction: column;
    ${p =>
      p.imagePos === 'left' &&
      `
      align-items: flex-end;
    `}
  }

  img {
    width: ${props => (props.imagePos === 'top' ? '300px' : '450px')};
    height: 300px;
    object-fit: cover;
  }

  h4 {
    text-transform: uppercase;
    margin-bottom: 2rem;
  }

  p {
    width: ${p => (p.imagePos === 'top' ? 'auto' : '60%')};
    text-align: ${p => (p.imagePos === 'left' ? 'right' : 'left')};
  }

  button {
    width: fit-content;
    margin-top: 2rem;
  }
`

interface Props {
  imagePos: 'left' | 'right' | 'top'
  title: string
  children: ReactNode
  button: string
  link: string
  image: string
  className?: string
}

const imageBlock = ({
  imagePos,
  image,
  title,
  children,
  button,
  link,
  className,
}: Props) => {
  return (
    <Container className={className} imagePos={imagePos}>
      <img src={image} />
      <div>
        <h4>{title}</h4>
        {children}
        <Link href={link}>
          <button>{button}</button>
        </Link>
      </div>
    </Container>
  )
}

export default imageBlock
