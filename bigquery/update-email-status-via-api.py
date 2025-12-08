"""
Update email_status via BigQuery API (Python)
Use this from external services to update email validation status
"""

from google.cloud import bigquery
from typing import List, Dict, Optional

# Initialize BigQuery client
client = bigquery.Client(project='n8n-revenueinstitute')

VALID_STATUSES = ['unverified', 'verified', 'accept_all', 'invalid']

def update_email_status(email: str, status: str) -> None:
    """Update a single email's validation status"""
    
    if status not in VALID_STATUSES:
        raise ValueError(f"Invalid status: {status}. Must be one of: {VALID_STATUSES}")
    
    query = """
        UPDATE `n8n-revenueinstitute.outbound_sales.leads`
        SET email_status = @status
        WHERE LOWER(TRIM(email)) = LOWER(TRIM(@email))
    """
    
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("email", "STRING", email),
            bigquery.ScalarQueryParameter("status", "STRING", status),
        ]
    )
    
    query_job = client.query(query, job_config=job_config)
    query_job.result()  # Wait for the query to finish
    
    print(f"✅ Updated email status for {email} to {status}")


def bulk_update_email_status(email_status_pairs: List[Dict[str, str]]) -> None:
    """
    Bulk update email statuses
    
    Args:
        email_status_pairs: List of dicts with 'email' and 'status' keys
        Example: [
            {'email': 'john@example.com', 'status': 'verified'},
            {'email': 'jane@company.com', 'status': 'invalid'}
        ]
    """
    
    if not email_status_pairs:
        raise ValueError("email_status_pairs must be a non-empty list")
    
    # Validate statuses
    for pair in email_status_pairs:
        if pair['status'] not in VALID_STATUSES:
            raise ValueError(f"Invalid status: {pair['status']}")
    
    # Build CASE statement
    case_statements = []
    query_params = []
    
    for i, pair in enumerate(email_status_pairs):
        case_statements.append(
            f"WHEN LOWER(TRIM(email)) = LOWER(TRIM(@email{i})) THEN @status{i}"
        )
        query_params.append(
            bigquery.ScalarQueryParameter(f"email{i}", "STRING", pair['email'])
        )
        query_params.append(
            bigquery.ScalarQueryParameter(f"status{i}", "STRING", pair['status'])
        )
    
    email_list = ", ".join([f"LOWER(TRIM(@email{i}))" for i in range(len(email_status_pairs))])
    
    query = f"""
        UPDATE `n8n-revenueinstitute.outbound_sales.leads`
        SET email_status = CASE
            {chr(10).join(['      ' + stmt for stmt in case_statements])}
            ELSE email_status
        END
        WHERE LOWER(TRIM(email)) IN ({email_list})
    """
    
    job_config = bigquery.QueryJobConfig(query_parameters=query_params)
    
    query_job = client.query(query, job_config=job_config)
    query_job.result()
    
    print(f"✅ Bulk updated {len(email_status_pairs)} email statuses")


def get_email_status(email: str) -> Optional[Dict]:
    """Get email validation status"""
    
    query = """
        SELECT 
            email,
            email_status,
            trackingId
        FROM `n8n-revenueinstitute.outbound_sales.leads`
        WHERE LOWER(TRIM(email)) = LOWER(TRIM(@email))
        LIMIT 1
    """
    
    job_config = bigquery.QueryJobConfig(
        query_parameters=[
            bigquery.ScalarQueryParameter("email", "STRING", email),
        ]
    )
    
    query_job = client.query(query, job_config=job_config)
    results = list(query_job.result())
    
    if not results:
        return None
    
    row = results[0]
    return {
        'email': row.email,
        'email_status': row.email_status,
        'trackingId': row.trackingId
    }


def get_status_counts() -> List[Dict]:
    """Get count of leads by email status"""
    
    query = """
        SELECT 
            email_status,
            COUNT(*) as count
        FROM `n8n-revenueinstitute.outbound_sales.leads`
        GROUP BY email_status
        ORDER BY count DESC
    """
    
    query_job = client.query(query)
    results = query_job.result()
    
    return [
        {'email_status': row.email_status, 'count': row.count}
        for row in results
    ]


# ============================================
# Example Usage
# ============================================

if __name__ == "__main__":
    # Update single email
    update_email_status('john@example.com', 'verified')
    
    # Bulk update
    bulk_update_email_status([
        {'email': 'john@example.com', 'status': 'verified'},
        {'email': 'jane@company.com', 'status': 'invalid'},
        {'email': 'team@startup.io', 'status': 'accept_all'}
    ])
    
    # Get status
    status = get_email_status('john@example.com')
    print(f"Email status: {status}")
    
    # Get counts
    counts = get_status_counts()
    print(f"Status distribution: {counts}")



