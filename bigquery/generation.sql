CREATE OR REPLACE FUNCTION `[DATASET].BulletsPrompt`(LANGUAGE STRING, EXAMPLES ARRAY<STRUCT<id STRING, bullets STRING, description STRING, properties STRING>>, PROPERTIES ARRAY<STRING>) AS (
CONCAT(
    """You are a leading digital marketer working for a top retail organisation.
You are an expert at generating high-performing bullet points and identifying the most important product attributes for influencing a buying decision.
Given the input product data below, for each described product generate a bullet list in """,
    LANGUAGE,
    """ formatted in HTML. Adhere to the following rules:
1) Provide a bullet list (minimum 3 points, maximum 6 points) of the product’s specifications and features, formatted in HTML using <ul> and <li> tags.
2) The bulletpoints need to be short and concise, as a supplement to a product description. 
3) Avoid adding extra line breaks or new lines between the tags. The entire HTML structure should be one continuous string.
4) Generate fewer than 6 bulletpoints if the available information is limited. 
5) Never generate less than 3 bulletpoints.  
5) Only state facts from the provided product information and do not add extra points to meet the maximum list length limit.
6) Keep the bullet points concise. Focus on specifications and features that offer value to the customer, avoiding direct repetition of the product description and current bulletpoints.
7) Exclude unnecessary details and prioritize what’s most relevant for a building materials retailer’s customers. Do not invent specifications that are not present in the product information.
8) Be precise and professional. Do not mention accessories. Avoid stating that information is missing; instead, omit any mention of unavailable data.
9) Avoid subjective opinions about the brand or product. Do not use words or expressions that do not make sense in the context. Include details about size, dimensions, or similar aspects only if explicitly stated in the product information. Use terms and names exactly as provided in the product information, such as “TX bit holder” or “T25 drive type.” Do not rephrase or replace these specifications.
10) Always include a space after the colon when prepending the product ID to the bullet list.

Let's first look at some examples of how to write good bullet points:""",
    "\n\nExample input product data:\n\n", ARRAY_TO_STRING(
      (SELECT ARRAY_AGG(properties) FROM UNNEST(EXAMPLES)), '\n', ''),
    "\n\nExample output product bullet points (adhering to all ten rules, in the same order as the input, prepended with the respective ID, but without headline, without empty lines, without indentation, without leading dashes):\n\n", ARRAY_TO_STRING(
      (SELECT ARRAY_AGG(CONCAT(id, ': ', bullets)) FROM UNNEST(EXAMPLES)), '\n', ''),
    """\n\n
Now let's tackle the actual task at hand:""",
    "\n\nActual input product data:\n\n", ARRAY_TO_STRING(PROPERTIES, '\n', ''),
    "\n\nActual output product bullets (adhering to all ten rules in the same order as the input, prepended with the respective ID, followed by the HTML output):\n\n"
    )
);

CREATE OR REPLACE FUNCTION `[DATASET].DescriptionsPrompt`(LANGUAGE STRING, EXAMPLES ARRAY<STRUCT<id STRING, bullets STRING, description STRING, properties STRING>>, PROPERTIES ARRAY<STRING>) AS (
CONCAT(
  """You are an expert product manager responsible for writing product descriptions for a leading home improvement retailer that increases the likelihood of purchase, without misleading the customer. The goal is to enrich the current product catalog descriptions with additional information from attributes and bulletpoints. Your expertise lies in creating precise, informative, and professional descriptions. Given the product data below, for each described product generate a detailed, significantly longer, and highly elaborate description in grammatically correct """,
  LANGUAGE,
  """ formatted in HTML. Adhere to the following rules:

  1. Title: Begin the description with a new title under 60 characters, based on the original product title.
     - Include the brand name and a relevant keyword for SEO optimization.
     - Maintain clarity and relevance to the product.
     - Only capitalize the first word of the title.

  2. Description Content:
     - Directly after the title (as the first line), write a description using all available product data, including description, bulletpoints, dimensions, materials, features, benefits, and other attributes.
     - Use SUBHEADINGS to separate the text into paragraphs. Each paragraph should not contain more than a few sentences. 
     - A new paragraph ALWAYS need a subheading before. 
     - If there are dimensions available, use a clear section header like `<h3>Dimensions</h3>` followed by a list with each dimension item in separate `<li>` tags inside a `<ul>` list, specifying the dimensions, for example bredde, lengde, høyde etc.
     - Do not create lists for any other attributes (e.g., features, benefits, materials). All other data should be included by being rewritten into a cohesive descriptive text.
     - Provide comprehensive information to ensure descriptions are at least 2-3 times longer than the input description.
     - When the attribute fields are populated, make sure to include this data in the description to add valuable information to the existing description.
     - If any attribute (such as dimensions, features, or specifications) is missing or unavailable, DO NOT include a placeholder or a sentence about missing data.
     - DO NOT include any references to external websites, downloadable materials, or guarantees unless explicitly mentioned in the input data.
     - If certain data points are missing, OMIT that section entirely. DO NOT mention that the data is unavailable or use filler text to compensate.
     - Use information from the image, such as color, brand, and product details, to enhance the description, but never explicitly mention the image as the source of the information.
     - Avoid phrases like "Bildet viser" or "Synlig i bildet" Instead, incorporate the details naturally into the product description.
    
  3. Length and Detail:
     - The length of the description must align with the amount of available product data:
        - Minimal Data: For products with very short input description, bulletpoints and/or attributes, the output description should remain concise (2-3 sentences) while fully utilizing the available details.
        - Moderate Data: For products with moderate input description, bulletpoints and/or attributes, the generated description should include multiple sentences (4-6 sentences) split into several paragraphs using the proper <p> tags and subheadings with <h3> tags, that elaborate on the properties provided, expanding on features, use cases, and benefits.
        - Comprehensive Data: For products with rich input description, bulletpoints and/or attributes, the description must be significantly expanded, using paragraphs with the proper <p> tags, subheadings with <h3> tags, and structured details to thoroughly explain the product.
     - Use the level of detail and complexity in the input data to determine the appropriate length of the description. Avoid overly elaborating on products with limited input data.
     - Highlight practical use cases or comparisons to emphasize functionality, but avoid focusing on aesthetic qualities unless relevant.
     - Clearly state if accessories are not included and can be purchased separately. Do not fabricate details or include statements about missing or unavailable information.
     - Maintain objectivity and avoid brand bias.
     - Include all provided dimensions and use numerical values as given.
     - Avoid repeating the same feature, benefit, or specification in multiple sections or subheadings unless it adds new context or detail.  
     - Use synonyms or rephrase when reiterating key points to maintain interest and avoid redundancy.  

  4. Tone and Language:
     - Use a professional, informative, positive, and friendly tone.
     - Avoid being overly assertive, advertising-like, or flowery. Focus on functionality.
     - Do not add unnecessary filler words.
     - Subheadings should be informative for the following paragraph with an engaging and friendly tone. These can be more advertisement-like compared to the rest of the text. 

  5. Formatting:
     - The output should be a continuous HTML string in the following format, with varying number of paragraphs, depending on the length of the generated description:
     `Id: <h2>SEO-optimized title goes here</h2><h3>Paragraph 1 header</h3><p>Paragraph 1 goes here</p><h3>Paragraph 2 header</h3><p>Paragraph 2 goes here</p>`. 
     - ALWAYS add a H3 subheading before a paragraph. 
     - DO NOT put line breaks between the title and description.
     - Titles and product names should only have the first word capitalized, following Norwegian styling rules.
     - Following Norwegian grammar, compound words are common and splitting compound words should be avoided.
     - DO NOT include empty lines, indentation, or leading dashes.
     - Always add a space after the colon when prepending the product ID to the description.
     - Include all dimensions and numerical values as provided in the data.
     - Every description should feel highly detailed, significantly expanded, and comprehensive.
     - ALWAYS add a line break before a new product ID.
     - DO NOT use <br> tags. 
     - NEVER break the line until the next product.
     - Ensure that there is only ONE space between sentences.

  Before looking at the actual product data to be processed, let’s look at some examples:""",
  "\n\nExample input product data:\n\n", ARRAY_TO_STRING(
    (SELECT ARRAY_AGG(properties) FROM UNNEST(EXAMPLES)), '\n', ''),
  "\n\nExample output product descriptions:\n\n", ARRAY_TO_STRING(
    (SELECT ARRAY_AGG(CONCAT(id, ': ', description)) FROM UNNEST(EXAMPLES)), '\n', ''),
  "\n\nNow let’s tackle the actual task at hand:",
  "\n\nActual input product data:\n\n", ARRAY_TO_STRING(PROPERTIES, '\n', ''),
  "\n\nActual output product descriptions (adhering to ALL 5 guidelines, in the same order as the input, prepended with the respective ID, but without empty lines, without indentation, without leading dashes, as a CONTINUOUS HTML string. Always add a linebreak after the description before beginning the next product. NEVER add any other linebreaks. Never put two spaces between sentences. It needs to be a continuous string. ):\n\n"
)
);


CREATE OR REPLACE PROCEDURE `[DATASET].BatchedUpdateBullets`(ITEMS_PER_PROMPT INT64, LANGUAGE STRING, PARTS INT64, PART INT64, IDS ARRAY<STRING>)
OPTIONS (strict_mode=false)
BEGIN
  DECLARE EXAMPLES ARRAY<STRUCT<id STRING, properties STRING, bullets STRING, description STRING>> DEFAULT (
    SELECT ARRAY_AGG(ExampleProducts) FROM '[DATASET]'.ExampleProducts
  );
  LOOP
    IF (
      SELECT COUNT(*) = 0 AND IDS IS NULL
      FROM '[DATASET]'.Output
      WHERE bullets IS NULL AND tries < 3
        AND (PARTS IS NULL OR ABS(MOD(FARM_FINGERPRINT(id), PARTS)) = PART)
    ) THEN LEAVE;
    END IF;

    -- Generate prompts
    CREATE OR REPLACE TEMP TABLE Prompts AS
    WITH
      Input AS (
        SELECT id, TO_JSON_STRING(I) AS properties
        FROM feedgen.Output AS O
        INNER JOIN feedgen.InputProcessing AS I USING (id)
        WHERE (PARTS IS NULL OR ABS(MOD(FARM_FINGERPRINT(id), PARTS)) = PART)
          AND IF(IDS IS NOT NULL,
            O.id IN UNNEST(IDS),
            O.bullets IS NULL AND O.tries < 3)
        ORDER BY RAND()
        LIMIT 600 
      ),
      Numbered AS (
        SELECT id, properties, ROW_NUMBER() OVER (ORDER BY id) - 1 AS row_id
        FROM Input
      )
    SELECT
      DIV(row_id, ITEMS_PER_PROMPT) AS chunk_id,
      feedgen.BulletsPrompt(LANGUAGE, EXAMPLES, ARRAY_AGG(properties ORDER BY id)) AS prompt,
      ARRAY_AGG(id ORDER BY id) AS ids
    FROM Numbered
    GROUP BY 1;

    -- Generate bullets
    CREATE OR REPLACE TEMP TABLE Generated AS
    SELECT ids, COALESCE(SPLIT(ml_generate_text_llm_result, '\n'), ids) AS output,
    FROM
      ML.GENERATE_TEXT(
        MODEL `[DATASET]`.GeminiPro,
        TABLE Prompts,
        STRUCT(
          0.1 AS temperature,
          2048 AS max_output_tokens,
          TRUE AS flatten_json_output));

    -- Store generated bullets in output feed
    MERGE feedgen.Output AS O
    USING (
      SELECT
        COALESCE(REGEXP_EXTRACT(output, r'^([^:]+): .*'), REGEXP_EXTRACT(output, r'^([^:]+)$')) AS id,
        REGEXP_EXTRACT(output, r'^[^:]+: (.*)$') AS bullets
      FROM Generated AS G
      CROSS JOIN G.output
      QUALIFY ROW_NUMBER() OVER (PARTITION BY id) = 1 AND id IN UNNEST(G.ids)
    ) AS G
      ON O.id = G.id
    WHEN MATCHED THEN UPDATE SET
      O.bullets = IFNULL(G.bullets, O.bullets),
      O.tries = O.tries + 1;

    IF IDS IS NOT NULL THEN LEAVE;
    END IF;
  END LOOP;
END;


CREATE OR REPLACE PROCEDURE `[DATASET].BatchedUpdateDescriptions`(ITEMS_PER_PROMPT INT64, LANGUAGE STRING, PARTS INT64, PART INT64, IDS ARRAY<STRING>)
OPTIONS (strict_mode=false)
BEGIN
  DECLARE EXAMPLES ARRAY<STRUCT<id STRING, bullets STRING, description STRING, properties STRING>> DEFAULT (
    SELECT ARRAY_AGG(ExampleProducts) FROM `[DATASET]`.ExampleProducts
  );
  LOOP
    IF (
      SELECT COUNT(*) = 0 AND IDS IS NULL
      FROM `[DATASET]`.Output
      WHERE description IS NULL AND tries < 3
        AND (PARTS IS NULL OR ABS(MOD(FARM_FINGERPRINT(id), PARTS)) = PART)
    ) THEN LEAVE;
    END IF;

    -- Generate prompts
    CREATE OR REPLACE TEMP TABLE Prompts AS
    WITH
      Input AS (
        SELECT id, TO_JSON_STRING(I) AS properties
        FROM `[DATASET]`.Output AS O
        INNER JOIN `[DATASET]`.InputProcessing AS I USING (id)
        WHERE (PARTS IS NULL OR ABS(MOD(FARM_FINGERPRINT(id), PARTS)) = PART)
          AND IF(IDS IS NOT NULL,
            O.id IN UNNEST(IDS),
            O.description IS NULL AND O.tries < 3)
        ORDER BY RAND()
        LIMIT 600 
      ),
      Numbered AS (
        SELECT id, properties, ROW_NUMBER() OVER (ORDER BY id) - 1 AS row_id
        FROM Input
      )
    SELECT
      DIV(row_id, ITEMS_PER_PROMPT) AS chunk_id,
      `[DATASET]`.DescriptionsPrompt(LANGUAGE, EXAMPLES, ARRAY_AGG(properties ORDER BY id)) AS prompt,
      ARRAY_AGG(id ORDER BY id) AS ids
    FROM Numbered
    GROUP BY 1;

    -- Generate descriptions
    CREATE OR REPLACE TEMP TABLE Generated AS
    SELECT ids, COALESCE(SPLIT(ml_generate_text_llm_result, '\n'), ids) AS output,
    FROM
      ML.GENERATE_TEXT(
        MODEL `[DATASET]`.GeminiPro,
        TABLE Prompts,
        STRUCT(
          0 AS temperature,
          4000 AS max_output_tokens,
          TRUE AS flatten_json_output));

    -- Store generated descriptions in output feed
    MERGE `[DATASET]`.Output AS O
    USING (
      SELECT
        COALESCE(REGEXP_EXTRACT(output, r'^([^:]+): .*'), REGEXP_EXTRACT(output, r'^([^:]+)$')) AS id,
        REGEXP_EXTRACT(output, r'^[^:]+: (.*)$') AS description
      FROM Generated AS G
      CROSS JOIN G.output
      QUALIFY ROW_NUMBER() OVER (PARTITION BY id) = 1 AND id IN UNNEST(G.ids)
    ) AS G
      ON O.id = G.id
    WHEN MATCHED THEN UPDATE SET
      O.description = IFNULL(G.description, O.description),
      O.tries = O.tries + 1;

    IF IDS IS NOT NULL THEN LEAVE;
    END IF;
  END LOOP;
END;