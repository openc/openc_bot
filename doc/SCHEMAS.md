# Financial licence

Licences give permissions to engage in certain regulated activities,
such as banking, selling or exporting restricted items, or exploiting
natural resources.

A financial licence is a licence given to entities in the financial
industries, for example to carry on as a bank, to sell or advise on
financial products, or to act as a broker for financial transactions.

The format your bot is expected to produce for a Financial Licence is:

    :sample_date
        required (if end_date is not provided)
    :start_date
        optional
    :start_date_type
        required if :start_date is present
        one of "=", "<", or ">"
    :end_date
        optional (if sample_date is provided)
    :end_date_type
        required if :end_date is present
        one of "=", "<", or ">"
    :company
        required
        a hash with the following keys:
            :name
                required
                a string of the name of the company
            :jurisdiction
                required
                a string of the jurisdiction
                    eg "us_ca"
    :source_url
        required
        a string of the URL of the data
    :data
        required
        an array with a single hash, with the following keys:
            :data_type
                required
                must be :licence
            :properties
                required
                a hash with the following keys:
                    :jurisdiction_code
                        required
                        the jurisdiction in which the licence was issued
                    :licence_number
                        optional
                    :regulator
                        optional
                        The regulating body that issued the licence
                    :jurisdiction_classification
                        required
                        an array of strings that describe the licence or the licenced company, using the vocabulary of the data source
                        examples might be:
                            foreign bank branch
                            co-operative credit
                            motor vehicle finance
                            trust company
                    :oc_classification
                        not required yet
                        an array of strings that describe the licence or the licenced company, taken from a vocabulary list provided by OpenCorporates (TBC)

# Share Parcel

Share parcels are shares issued by a company to other people or
companies. When a person or company owns more than 50% of all the
issued shares in a company, they are usually said to control that
company. Owners with lower percentages can still exert significant
influence.

    :sample_date
        required (if end_date is not provided)
    :start_date
        optional
    :start_date_type
        required if :start_date is present
        one of "=", "<", or ">"
    :end_date
        optional (if sample_date is provided)
    :end_date_type
        required if :end_date is present
        one of "=", "<", or ">"
    :company
        required
        a hash with the following keys:
            :name
                required
                a string of the name of the company that has issued the shares
            :jurisdiction
                required
                a string of the jurisdiction
                    eg "us_ca"
    :source_url
        required
        a string of the URL of the data
    :data
        required
        an array with a single hash, with the following keys:
            :data_type
                required
                must be :share_parcel
            :properties
                required
                a hash with the following keys:
                    :number_of_shares
                        optional
                    :percentage_of_shares
                        optional
                    :shareholders
                        required
                        an array hashes listing single or joint shareholders, with the following keys:
                            :name
                                name of person or company
                            :jurisdiction
                                optional
                                jurisdiction, if it's a company
                            :company_number
                                optional
                            :identifier
                                optional
                                a unique identifier for the person or company
                            :type
                               optional
                               must be "Company" or "Person"
                            :address
                               given address for parcel owner
                            :address_country
                               given country for parcel owner


# Subsidiary

A subsidiary is a company that is controlled by another company. Often
the control is exerted via a majority shareholding, but can be via
other mechanisms. It can also be exerted via shareholdings in other
companies. When this happens, we call it an indirect
subsidiary. Subsidiary information often comes from official annual
reports. Companies are only obliged to report "significant"
subsidiaries, and the definition of "significant" is not consistent.

It may also come from other regulatory documents (financial,
environmental, etc)

    :sample_date
        required (if end_date is not provided)
    :start_date
        optional
    :start_date_type
        required if :start_date is present
        one of "=", "<", or ">"
    :end_date
        optional (if sample_date is provided)
    :end_date_type
        required if :end_date is present
        one of "=", "<", or ">"
    :company
        required
        a hash with the following keys:
            :name
                required
                a string of the name of the company
            :jurisdiction
                required
                a string of the jurisdiction
                    eg "us_ca"
    :source_url
        required
        a string of the URL of the data
    :data
        required
        an array with a single hash, with the following keys:
            :data_type
                required
                must be :subsidiary_relationship
            :properties
                required
                a hash with the following keys:
                    :direct
                        optional
                        If the control is direct (if via an intermediary, this value should be false; if unknown, left blank)
                    :significant
                        optional
                        Does the source define the control as somehow significant?
                    :subsidiary
                        required
                        a hash describing the subsidiary
                            :name
                                name of person or company
                            :jurisdiction
                                optional
                                jurisdiction, if it's a company
                            :company_number
                                optional
                            :identifier
                                optional
                                a unique identifier for the person or company
                            :address
                               given address for parcel owner
                            :address_country
                               given country for parcel owner
