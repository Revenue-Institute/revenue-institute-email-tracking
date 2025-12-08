/**
 * Update email_status via BigQuery API
 * Use this from external services to update email validation status
 */

const { BigQuery } = require('@google-cloud/bigquery');

const bigquery = new BigQuery({
  projectId: 'n8n-revenueinstitute',
  // Credentials loaded from GOOGLE_APPLICATION_CREDENTIALS env var
  // or from default service account
});

/**
 * Update a single email's status
 */
async function updateEmailStatus(email, status) {
  const validStatuses = ['unverified', 'verified', 'accept_all', 'invalid'];
  
  if (!validStatuses.includes(status)) {
    throw new Error(`Invalid status: ${status}. Must be one of: ${validStatuses.join(', ')}`);
  }

  const query = `
    UPDATE \`n8n-revenueinstitute.outbound_sales.leads\`
    SET email_status = @status
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(@email))
  `;

  const options = {
    query: query,
    params: { email, status }
  };

  const [job] = await bigquery.createQueryJob(options);
  const [rows] = await job.getQueryResults();
  
  console.log(`✅ Updated email status for ${email} to ${status}`);
  return rows;
}

/**
 * Bulk update email statuses from array
 */
async function bulkUpdateEmailStatus(emailStatusPairs) {
  // emailStatusPairs format: [{ email: 'john@ex.com', status: 'verified' }, ...]
  
  if (!Array.isArray(emailStatusPairs) || emailStatusPairs.length === 0) {
    throw new Error('emailStatusPairs must be a non-empty array');
  }

  // Build CASE statement for bulk update
  const caseStatements = emailStatusPairs.map((pair, i) => 
    `WHEN LOWER(TRIM(email)) = LOWER(TRIM(@email${i})) THEN @status${i}`
  ).join('\n      ');

  const query = `
    UPDATE \`n8n-revenueinstitute.outbound_sales.leads\`
    SET email_status = CASE
      ${caseStatements}
      ELSE email_status
    END
    WHERE LOWER(TRIM(email)) IN (${emailStatusPairs.map((_, i) => `LOWER(TRIM(@email${i}))`).join(', ')})
  `;

  // Build params object
  const params = {};
  emailStatusPairs.forEach((pair, i) => {
    params[`email${i}`] = pair.email;
    params[`status${i}`] = pair.status;
  });

  const options = {
    query: query,
    params: params
  };

  const [job] = await bigquery.createQueryJob(options);
  const [rows] = await job.getQueryResults();
  
  console.log(`✅ Bulk updated ${emailStatusPairs.length} email statuses`);
  return rows;
}

/**
 * Get email validation status
 */
async function getEmailStatus(email) {
  const query = `
    SELECT 
      email,
      email_status,
      trackingId
    FROM \`n8n-revenueinstitute.outbound_sales.leads\`
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(@email))
    LIMIT 1
  `;

  const options = {
    query: query,
    params: { email }
  };

  const [rows] = await bigquery.query(options);
  
  if (rows.length === 0) {
    return null;
  }
  
  return rows[0];
}

/**
 * Get count by email status
 */
async function getStatusCounts() {
  const query = `
    SELECT 
      email_status,
      COUNT(*) as count
    FROM \`n8n-revenueinstitute.outbound_sales.leads\`
    GROUP BY email_status
    ORDER BY count DESC
  `;

  const [rows] = await bigquery.query(query);
  return rows;
}

// ============================================
// Example Usage
// ============================================

async function example() {
  try {
    // Update single email
    await updateEmailStatus('john@example.com', 'verified');
    
    // Bulk update
    await bulkUpdateEmailStatus([
      { email: 'john@example.com', status: 'verified' },
      { email: 'jane@company.com', status: 'invalid' },
      { email: 'team@startup.io', status: 'accept_all' }
    ]);
    
    // Get status
    const status = await getEmailStatus('john@example.com');
    console.log('Email status:', status);
    
    // Get counts
    const counts = await getStatusCounts();
    console.log('Status distribution:', counts);
    
  } catch (error) {
    console.error('Error:', error);
  }
}

// Export functions for use in other modules
module.exports = {
  updateEmailStatus,
  bulkUpdateEmailStatus,
  getEmailStatus,
  getStatusCounts
};

// Run example if called directly
if (require.main === module) {
  example();
}



