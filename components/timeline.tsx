import React, { useState, ReactNode } from 'react'
import styled from 'styled-components'
import Lightbox from 'react-image-lightbox'

const YearContainer = styled.section`
  display: flex;
  img.main {
    flex: 1 1 0;
    width: calc(50% - 4.125rem);
    max-height: 300px;
    object-fit: cover;
  }
  div {
    border-right: 0.25rem dashed ${p => p.theme.colors.primaryText};
    margin: 0 4rem;
    width: 0px;
    flex-basis: 0;
  }
  aside {
    flex: 1 1 0;
    width: calc(50% - 4.125rem);
    h5 {
      margin-bottom: 2rem;
    }
  }
`

interface YearProps {
  image: string
  children: ReactNode
  className?: string
  gallery: Array<any>
}

export const Year = ({ children, image, className, gallery }: YearProps) => {
  const [modalOpen, setModalOpen] = useState(false)
  const [photoIndex, setPhotoIndex] = useState(0)
  return (
    <YearContainer className={className}>
      <img
        className="main"
        src={image}
        onClick={() => {
          setModalOpen(true)
        }}
      />
      <div />
      <aside>{children}</aside>
      {gallery.length && modalOpen && (
        <Lightbox
          mainSrc={gallery[photoIndex].gallery_image.url}
          nextSrc={gallery[(photoIndex + 1) % gallery.length].gallery_image.url}
          prevSrc={
            gallery[(photoIndex + gallery.length - 1) % gallery.length]
              .gallery_image.url
          }
          onCloseRequest={() => setModalOpen(false)}
          onMovePrevRequest={() =>
            setPhotoIndex((photoIndex + gallery.length - 1) % gallery.length)
          }
          onMoveNextRequest={() =>
            setPhotoIndex((photoIndex + 1) % gallery.length)
          }
        />
      )}
    </YearContainer>
  )
}

const Timeline = styled.article`
  display: flex;
  flex-direction: column;

  & > :nth-child(2n) {
    flex-direction: row-reverse;
  }
`

export default Timeline
