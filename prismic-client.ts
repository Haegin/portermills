import Prismic from 'prismic-javascript'

const apiEndpoint = 'https://porter-mills.cdn.prismic.io/api/v2'
const accessToken = process.env.PRISMIC_TOKEN

const Client = Prismic.client(apiEndpoint, { accessToken })

export default Client
